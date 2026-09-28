import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class HookTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.cwd = Path(self.temp.name)
        self.bin = self.cwd / 'bin'
        self.bin.mkdir()
        cli = self.bin / 'goldsky'
        cli.write_text('''#!/bin/bash
printf '%s\\n' "$*" >> "$CALLS"
if [[ "$1 $2" == "turbo validate" ]]; then
  exit "${VALIDATE_EXIT:-0}"
fi
if [[ "$1 $2" == "secret list" ]]; then
  printf '%s\\n' "$SECRET_LIST"
  exit "${SECRET_EXIT:-0}"
fi
exit 99
''')
        cli.chmod(0o755)
        self.env = {**os.environ, 'PATH': f'{self.bin}:/usr/bin:/bin',
                    'CALLS': str(self.cwd / 'calls'),
                    'SECRET_LIST': '│ Name │ Type │ Variant │\n│ db.prod │ postgres │ default │'}
        jq = shutil.which('jq')
        self.assertIsNotNone(jq)
        (self.bin / 'jq').symlink_to(jq)
        (self.cwd / 'pipeline file.yaml').write_text('name: test\nsinks:\n  db:\n    secret_name: db.prod\n')

    def run_hook(self, script, host, command='goldsky turbo apply "pipeline file.yaml"', payload=None, raw=None):
        data = {'cwd': str(self.cwd)}
        data.update({'command': command} if host == 'cursor' else {'tool_input': {'command': command}})
        data.update(payload or {})
        return subprocess.run(['bash', str(ROOT / 'hooks/scripts' / f'{script}.sh'), host],
                              input=raw if raw is not None else json.dumps(data),
                              text=True, capture_output=True, env=self.env, cwd=ROOT)

    def assert_allowed(self, result, host):
        self.assertEqual(result.returncode, 0, result.stderr)
        if host == 'cursor':
            self.assertEqual(json.loads(result.stdout), {'permission': 'allow'})
        else:
            self.assertEqual(result.stdout, '')

    def assert_blocked(self, result, host):
        if host == 'cursor':
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(json.loads(result.stdout)['permission'], 'deny')
        else:
            self.assertEqual(result.returncode, 2, result.stderr)
        self.assertTrue(result.stderr)

    def test_valid_pipeline_and_existing_secret(self):
        for host in ['claude', 'cursor']:
            for script in ['pre-deploy-validate', 'secret-check']:
                with self.subTest(host=host, script=script):
                    self.assert_allowed(self.run_hook(script, host), host)
        self.assertIn('turbo validate pipeline file.yaml', (self.cwd / 'calls').read_text())
        self.assertIn('secret list --no-color', (self.cwd / 'calls').read_text())

    def test_single_quotes_and_file_flags(self):
        for host in ['claude', 'cursor']:
            for args in ["'pipeline file.yaml'", "-f 'pipeline file.yaml'", '--file "pipeline file.yaml"']:
                self.assert_allowed(self.run_hook('pre-deploy-validate', host, 'goldsky turbo apply ' + args), host)
        self.assertEqual(len((self.cwd / 'calls').read_text().splitlines()), 6)

    def test_validation_failure_and_missing_file(self):
        for host in ['claude', 'cursor']:
            self.assert_blocked(self.run_hook('pre-deploy-validate', host, 'goldsky turbo apply absent.yaml'), host)
            self.env['VALIDATE_EXIT'] = '1'
            self.assert_blocked(self.run_hook('pre-deploy-validate', host), host)

    def test_no_secret_references_does_not_call_cli(self):
        (self.cwd / 'pipeline file.yaml').write_text('name: test\n')
        for host in ['claude', 'cursor']:
            self.assert_allowed(self.run_hook('secret-check', host), host)
        self.assertFalse((self.cwd / 'calls').exists())

    def test_secret_names_are_literal_and_empty_project_blocks(self):
        for listing in ['│ Name │ Type │\n│ dbXprod │ postgres │',
                        'No secrets found. Create one with goldsky secret create.']:
            self.env['SECRET_LIST'] = listing
            for host in ['claude', 'cursor']:
                self.assert_blocked(self.run_hook('secret-check', host), host)

    def test_secret_table_formats_in_byte_and_default_locales(self):
        for separator in ['│', '|']:
            for locale in ['C', os.environ.get('LC_ALL', '')]:
                with self.subTest(separator=separator, locale=locale):
                    self.env['LC_ALL'] = locale
                    self.env['SECRET_LIST'] = f'\x1b[32m{separator} Name {separator} Type {separator}\x1b[0m\n{separator} db.prod {separator} postgres {separator}'
                    self.assert_allowed(self.run_hook('secret-check', 'cursor'), 'cursor')
                    self.env['SECRET_LIST'] = self.env['SECRET_LIST'].replace('db.prod', 'other')
                    self.assert_blocked(self.run_hook('secret-check', 'cursor'), 'cursor')

    def test_quoted_secrets_and_comments(self):
        for quote in ["'", '"', '']:
            (self.cwd / 'pipeline file.yaml').write_text(f'  secret_name: {quote}missing{quote} # comment\n')
            self.assert_blocked(self.run_hook('secret-check', 'cursor'), 'cursor')

    def test_secret_cli_failure_and_unknown_format_skip(self):
        for listing, code in [('network error', '1'), ('new format', '0'), ('Name | Type', '0'), ('', '0')]:
            self.env.update(SECRET_LIST=listing, SECRET_EXIT=code)
            for host in ['claude', 'cursor']:
                self.assert_allowed(self.run_hook('secret-check', host), host)

    def test_unsupported_commands_never_execute_input(self):
        for command in ['echo goldsky turbo apply absent.yaml', 'goldsky turbo apply',
                        'goldsky turbo apply "$FILE.yaml"',
                        'goldsky turbo apply $(touch injected).yaml',
                        'cd /tmp && goldsky turbo apply absent.yaml',
                        'goldsky turbo apply absent.yaml; touch injected']:
            for host in ['claude', 'cursor']:
                for script in ['pre-deploy-validate', 'secret-check']:
                    self.assert_allowed(self.run_hook(script, host, command), host)
        self.assertFalse((self.cwd / 'calls').exists())
        self.assertFalse((self.cwd / 'injected').exists())

    def test_malformed_input_and_missing_command_skip(self):
        for raw in ['invalid json', '{}', '{"command":42}', '{"command":null}']:
            for host in ['claude', 'cursor']:
                for script in ['pre-deploy-validate', 'secret-check']:
                    self.assert_allowed(self.run_hook(script, host, raw=raw), host)

    def test_hook_manifest_commands_work_with_spaces_in_plugin_path(self):
        plugin = self.cwd / 'plugin folder'
        plugin.symlink_to(ROOT, target_is_directory=True)
        for host, config, event, variable in [
            ('cursor', 'cursor-hooks.json', 'beforeShellExecution', 'CURSOR_PLUGIN_ROOT'),
            ('claude', 'hooks.json', 'PreToolUse', 'CLAUDE_PLUGIN_ROOT')
        ]:
            entries = json.loads((ROOT / 'hooks' / config).read_text())['hooks'][event]
            hooks = entries if host == 'cursor' else entries[0]['hooks']
            command = 'goldsky turbo apply "pipeline file.yaml"'
            payload = {'cwd': str(self.cwd)}
            payload.update({'command': command} if host == 'cursor' else {'tool_input': {'command': command}})
            for hook in hooks:
                result = subprocess.run(hook['command'], shell=True, input=json.dumps(payload),
                                        capture_output=True, text=True, cwd=ROOT,
                                        env={**self.env, variable: str(plugin)})
                self.assert_allowed(result, host)
        self.assertEqual(len((self.cwd / 'calls').read_text().splitlines()), 4)

    def test_missing_cli_skips(self):
        (self.bin / 'goldsky').unlink()
        for host in ['claude', 'cursor']:
            for script in ['pre-deploy-validate', 'secret-check']:
                self.assert_allowed(self.run_hook(script, host), host)

    def test_missing_jq_skips_with_valid_cursor_json(self):
        (self.bin / 'jq').unlink()
        (self.bin / 'cat').symlink_to('/bin/cat')
        (self.bin / 'dirname').symlink_to('/usr/bin/dirname')
        self.env['PATH'] = str(self.bin)
        (self.bin / 'bash').symlink_to('/bin/bash')
        for host in ['claude', 'cursor']:
            for script in ['pre-deploy-validate', 'secret-check']:
                self.assert_allowed(self.run_hook(script, host), host)

    def test_post_deploy_reads_each_hosts_output(self):
        for host, payload in [('claude', {'tool_response': {'stdout': 'Applied "test"', 'stderr': '', 'interrupted': False}}),
                              ('cursor', {'output': 'Applied "test"'})]:
            result = self.run_hook('post-deploy-inspect', host, payload=payload)
            self.assertEqual(result.returncode, 0, result.stderr)
            if host == 'claude':
                self.assertIn('goldsky turbo inspect', json.loads(result.stdout)['hookSpecificOutput']['additionalContext'])
            else:
                self.assertEqual(json.loads(result.stdout), {})
                self.assertIn('goldsky turbo inspect', result.stderr)

    def test_post_deploy_skips_failure_interruption_and_missing_output(self):
        for payload in [{}, {'output': 'Validation failed: "bad"'},
                        {'output': 'done', 'exit_code': 1},
                        {'tool_response': {'stdout': 'done', 'interrupted': True}},
                        {'tool_response': {'stdout': '', 'stderr': 'error'}}]:
            for host in ['claude', 'cursor']:
                result = self.run_hook('post-deploy-inspect', host, payload=payload)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout, '')


if __name__ == '__main__':
    unittest.main()
