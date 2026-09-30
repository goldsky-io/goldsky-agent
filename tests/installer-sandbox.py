"""Run as root in a disposable Linux container; each test gets a fresh user."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
import uuid

INSTALLER = Path(__file__).resolve().parents[1] / 'skills/auth-setup/scripts/install.sh'

CURL = r'''#!/bin/bash
set -eu
url= output=
while [ "$#" -gt 0 ]; do
  case "$1" in
    https:*) url=$1 ;;
    --output) shift; output=$1 ;;
  esac
  shift
done
case "$url" in
  https://goldsky.com) component=goldsky ;;
  https://compose.goldsky.com/install) component=compose ;;
  https://install-turbo.goldsky.com) component=turbo ;;
  *) exit 90 ;;
esac
if [ "${TEST_FAIL:-}" = "$component" ]; then exit 22; fi
if [ "${TEST_EMPTY:-}" = "$component" ]; then : > "$output"; exit 0; fi
if [ "$component" = goldsky ]; then
cat > "$output" <<'SCRIPT'
#!/bin/bash
set -eu
test "$1" = -f
cat > "$GOLDSKY_INSTALL_DIR/goldsky" <<'BIN'
#!/bin/bash
if [ "${1:-}" = --version ]; then echo '13.15.1'; exit 0; fi
exec "$HOME/.goldsky/bin/$1" "${@:2}"
BIN
chmod +x "$GOLDSKY_INSTALL_DIR/goldsky"
SCRIPT
else
cat > "$output" <<SCRIPT
#!/bin/bash
set -eu
cat > "\$HOME/.goldsky/bin/$component" <<'BIN'
#!/bin/sh
echo fixture-version
BIN
chmod +x "\$HOME/.goldsky/bin/$component"
SCRIPT
if [ "${TEST_BROKEN:-}" = "$component" ]; then
  printf 'printf "#!/bin/sh\\nexit 1\\n" > "$HOME/.goldsky/bin/%s"\n' "$component" >> "$output"
fi
fi
'''


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.user = 'gs' + uuid.uuid4().hex[:10]
        subprocess.run(['useradd', '-m', self.user], check=True)
        self.user_dir = Path('/home') / self.user
        self.temp = tempfile.TemporaryDirectory()
        self.bin = Path(self.temp.name)
        self.bin.chmod(0o755)
        for name, source in {
            'curl': CURL,
            'uname': '#!/bin/sh\ncase "$1" in -s) echo "${TEST_OS:-Linux}";; -m) echo "${TEST_ARCH:-x86_64}";; esac\n',
            'getconf': '#!/bin/sh\necho "${TEST_LIBC:-glibc 2.39}"\n',
        }.items():
            path = self.bin / name
            path.write_text(source)
            path.chmod(0o755)

    def tearDown(self):
        subprocess.run(['userdel', '-r', self.user], check=True, capture_output=True)
        self.temp.cleanup()

    def run_setup(self, component='all', **env):
        values = [f'PATH={self.bin}:/usr/bin:/bin'] + [f'{k}={v}' for k, v in env.items()]
        return subprocess.run(['runuser', '-u', self.user, '--', 'env', *values, 'bash', str(INSTALLER), component],
                              text=True, capture_output=True, timeout=20)

    def assert_success(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('Requested components verified', result.stdout)

    def test_full_install_and_repeat(self):
        self.assert_success(self.run_setup())
        self.assert_success(self.run_setup(TEST_FAIL='goldsky'))

    def test_goldsky_download_failure(self):
        result = self.run_setup(TEST_FAIL='goldsky')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.user_dir / '.local/bin/goldsky').exists())

    def test_empty_download(self):
        result = self.run_setup(TEST_EMPTY='goldsky')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Empty download', result.stderr)

    def test_turbo_download_failure(self):
        result = self.run_setup(TEST_FAIL='turbo')
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('Requested components verified', result.stdout)

    def test_compose_download_failure(self):
        self.assertNotEqual(self.run_setup(TEST_FAIL='compose').returncode, 0)

    def test_broken_turbo_binary(self):
        self.assertNotEqual(self.run_setup(TEST_BROKEN='turbo').returncode, 0)
        self.assert_success(self.run_setup())

    def test_broken_compose_binary(self):
        self.assertNotEqual(self.run_setup(TEST_BROKEN='compose').returncode, 0)
        self.assert_success(self.run_setup())

    def test_arm_full_install_incomplete(self):
        result = self.run_setup(TEST_ARCH='aarch64')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('no published Linux ARM binary', result.stderr)
        self.assertTrue((self.user_dir / '.goldsky/bin/compose').exists())
        self.assertFalse((self.user_dir / '.goldsky/bin/turbo').exists())

    def test_cli_only(self):
        self.assert_success(self.run_setup('cli', TEST_ARCH='aarch64'))
        self.assertFalse((self.user_dir / '.goldsky/bin/compose').exists())
        self.assertFalse((self.user_dir / '.goldsky/bin/turbo').exists())

    def test_arm_compose_only(self):
        self.assert_success(self.run_setup('compose', TEST_ARCH='aarch64'))

    def test_old_glibc(self):
        result = self.run_setup(TEST_LIBC='glibc 2.36')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('glibc 2.39+', result.stderr)

    def test_musl(self):
        self.assertNotEqual(self.run_setup(TEST_LIBC='musl').returncode, 0)

    def test_mac_platform_branch(self):
        self.assert_success(self.run_setup(TEST_OS='Darwin', TEST_ARCH='arm64', TEST_LIBC=''))

    def test_invalid_component(self):
        self.assertEqual(self.run_setup('unknown').returncode, 2)


if __name__ == '__main__':
    if os.geteuid() != 0 or not Path('/.dockerenv').exists():
        raise SystemExit('Run only in a disposable Linux Docker container as root.')
    unittest.main()
