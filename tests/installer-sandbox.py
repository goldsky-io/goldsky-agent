"""Installer contract tests. No network and no root required."""
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INSTALLER = ROOT / 'skills/auth-setup/scripts/install.sh'
INSTALL_PS1 = ROOT / 'skills/auth-setup/scripts/install.ps1'

NPM = r'''#!/bin/bash
set -eu
printf '%s\n' "$*" >> "$NPM_LOG"
prefix=
pkg=
prev=
for arg in "$@"; do
  if [ "$prev" = --prefix ]; then prefix=$arg; prev=; continue; fi
  case "$arg" in
    --prefix) prev=--prefix ;;
    --prefix=*) prefix=${arg#--prefix=} ;;
    @goldskycom/cli@13.17.0) pkg=$arg ;;
    *@latest*|@latest) echo 'refusing @latest' >&2; exit 91 ;;
  esac
done
[ "${1:-}" = install ]
[ "$pkg" = @goldskycom/cli@13.17.0 ]
[ -n "$prefix" ]
if [ "${TEST_NPM_FAIL:-}" = 1 ]; then echo 'npm install failed' >&2; exit 22; fi
mkdir -p "$prefix/bin"
cat > "$prefix/bin/goldsky" <<'BIN'
#!/bin/bash
set -eu
printf '%s\n' "$*" >> "$GOLDSKY_LOG"
cmd="${1:-}"
sub="${2:-}"
case "$cmd" in
  --version)
    if [ "${TEST_CLI_VERSION_FAIL:-}" = 1 ]; then exit 1; fi
    printf '%s\n' "${TEST_CLI_VERSION:-13.17.0}"
    ;;
  compose)
    case "$sub" in
      install)
        if [ "${TEST_COMPOSE_FAIL:-}" = 1 ]; then echo 'compose install failed' >&2; exit 1; fi
        ;;
      --version)
        if [ "${TEST_COMPOSE_VERSION_FAIL:-}" = 1 ]; then exit 1; fi
        echo 'goldsky compose fixture'
        ;;
      *) echo "unexpected compose args: $*" >&2; exit 1 ;;
    esac
    ;;
  turbo)
    case "$sub" in
      install)
        if [ "${TEST_TURBO_MISSING:-}" = 1 ]; then
          echo '`install` is not a Goldsky Turbo command.' >&2
          exit 0
        fi
        if [ "${TEST_TURBO_PIPE:-}" = 1 ]; then
          echo 'Please install it by running: curl https://example.invalid | sh' >&2
          exit 1
        fi
        if [ "${TEST_TURBO_FAIL:-}" = 1 ]; then echo 'turbo install failed' >&2; exit 1; fi
        ;;
      --version)
        if [ "${TEST_TURBO_VERSION_FAIL:-}" = 1 ]; then exit 1; fi
        echo 'turbo fixture'
        ;;
      *) echo "unexpected turbo args: $*" >&2; exit 1 ;;
    esac
    ;;
  *) echo "unexpected goldsky args: $*" >&2; exit 1 ;;
esac
BIN
chmod +x "$prefix/bin/goldsky"
'''

CURL = r'''#!/bin/bash
set -eu
printf '%s\n' "$*" >> "$CURL_LOG"
exit 99
'''

UNAME = r'''#!/bin/sh
if [ "${1:-}" = -s ]; then
  if [ -n "${TEST_OS:-}" ]; then
    printf '%s\n' "$TEST_OS"
  else
    /usr/bin/uname -s
  fi
fi
'''


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        root = Path(self.temp.name)
        self.home = root / 'home'
        self.bin = root / 'bin'
        self.home.mkdir()
        self.bin.mkdir()
        self.npm_log = root / 'npm.log'
        self.goldsky_log = root / 'goldsky.log'
        self.curl_log = root / 'curl.log'
        self.write_bin('uname', UNAME)
        self.write_bin('curl', CURL)
        os.symlink(shutil.which('mkdir'), self.bin / 'mkdir')
        os.symlink(shutil.which('cat'), self.bin / 'cat')
        os.symlink(shutil.which('chmod'), self.bin / 'chmod')
        decoy = self.bin / 'goldsky'
        decoy.write_text('#!/bin/sh\necho 9.9.9\n')
        decoy.chmod(0o755)

    def tearDown(self):
        self.temp.cleanup()

    def write_bin(self, name, source):
        path = self.bin / name
        path.write_text(source)
        path.chmod(0o755)

    def run_setup(self, *args, include_npm=True, **env):
        if include_npm:
            self.write_bin('npm', NPM)
        elif (self.bin / 'npm').exists():
            (self.bin / 'npm').unlink()
        for log in (self.npm_log, self.goldsky_log, self.curl_log):
            log.write_text('')
        values = {
            'HOME': str(self.home),
            'PATH': str(self.bin),
            'NPM_LOG': str(self.npm_log),
            'GOLDSKY_LOG': str(self.goldsky_log),
            'CURL_LOG': str(self.curl_log),
            **env,
        }
        return subprocess.run(
            ['/bin/bash', str(INSTALLER), *args],
            text=True,
            capture_output=True,
            timeout=20,
            env=values,
        )

    def assert_success(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('Requested components verified', result.stdout)
        self.assertIn('export PATH="$HOME/.local/bin:$HOME/.goldsky/bin:$PATH"', result.stdout)
        self.assertEqual(self.curl_log.read_text(), '')
        self.assertNotIn('9.9.9', result.stdout)

    def test_scripts_do_not_fetch_an_installer(self):
        text = INSTALLER.read_text() + '\n' + INSTALL_PS1.read_text()
        for needle in (
            'curl',
            'wget',
            'https://goldsky.com',
            'compose.goldsky.com',
            'install-turbo.goldsky.com',
            '@latest',
            '| sh',
            '| bash',
            'sudo',
        ):
            self.assertNotIn(needle, text)
        self.assertIn(
            'npm install --global --prefix "$HOME/.local" @goldskycom/cli@13.17.0',
            INSTALLER.read_text(),
        )

    def test_missing_npm_exits_1(self):
        result = self.run_setup(include_npm=False)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn('npm is required.', result.stderr)
        self.assertNotIn('Requested components verified', result.stdout)
        self.assertEqual(self.curl_log.read_text(), '')
        self.assertFalse((self.home / '.local/bin/goldsky').exists())

    def test_full_install_and_repeat(self):
        self.assert_success(self.run_setup())
        npm_args = self.npm_log.read_text().strip()
        self.assertIn('--global', npm_args)
        self.assertIn(f'--prefix {self.home / ".local"}', npm_args)
        self.assertIn('@goldskycom/cli@13.17.0', npm_args)
        commands = self.goldsky_log.read_text().splitlines()
        self.assertIn('compose install', commands)
        self.assertIn('turbo install', commands)
        self.assertIn('--version', commands)
        self.assert_success(self.run_setup())

    def test_cli_only_skips_extensions(self):
        self.assert_success(self.run_setup('cli'))
        commands = self.goldsky_log.read_text().splitlines()
        self.assertNotIn('compose install', commands)
        self.assertNotIn('turbo install', commands)

    def test_compose_only(self):
        self.assert_success(self.run_setup('compose'))
        commands = self.goldsky_log.read_text().splitlines()
        self.assertIn('compose install', commands)
        self.assertNotIn('turbo install', commands)

    def test_turbo_only(self):
        self.assert_success(self.run_setup('turbo'))
        commands = self.goldsky_log.read_text().splitlines()
        self.assertNotIn('compose install', commands)
        self.assertIn('turbo install', commands)

    def test_missing_turbo_install_exits_1(self):
        result = self.run_setup(TEST_TURBO_MISSING='1')
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn('goldsky turbo install is not available', result.stderr)
        self.assertNotIn('Requested components verified', result.stdout)
        self.assertEqual(self.curl_log.read_text(), '')

    def test_turbo_pipe_instruction_is_not_relayed(self):
        result = self.run_setup(TEST_TURBO_PIPE='1')
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertNotIn('example.invalid', result.stdout + result.stderr)
        self.assertIn('goldsky turbo install failed.', result.stderr)
        self.assertEqual(self.curl_log.read_text(), '')

    def test_turbo_install_failure(self):
        result = self.run_setup(TEST_TURBO_FAIL='1')
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('Requested components verified', result.stdout)

    def test_compose_install_failure(self):
        result = self.run_setup(TEST_COMPOSE_FAIL='1')
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('Requested components verified', result.stdout)
        self.assertEqual(self.curl_log.read_text(), '')

    def test_npm_failure(self):
        result = self.run_setup(TEST_NPM_FAIL='1')
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('Requested components verified', result.stdout)
        self.assertFalse((self.home / '.local/bin/goldsky').exists())

    def test_wrong_cli_version(self):
        result = self.run_setup(TEST_CLI_VERSION='0.0.1')
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn('Expected Goldsky CLI 13.17.0.', result.stderr)

    def test_invalid_component(self):
        self.assertEqual(self.run_setup('unknown').returncode, 2)

    def test_extra_argument(self):
        self.assertEqual(self.run_setup('cli', 'turbo').returncode, 2)

    def test_windows_without_wsl(self):
        result = self.run_setup(TEST_OS='MINGW64_NT-10.0', include_npm=False)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn('WSL', result.stderr)


if __name__ == '__main__':
    unittest.main()
