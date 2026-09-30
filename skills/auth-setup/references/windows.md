# Windows installation

The complete Goldsky toolset runs inside WSL. The base CLI has a Windows npm package and Turbo publishes a Windows executable, but Compose currently has no native Windows artifact. Do not mix Windows binaries or credentials with a WSL installation.

Use an installed, initialized **x64 Ubuntu 24.04+** distribution for all three components. Linux ARM64 WSL can install Goldsky and Compose, but the published Turbo Linux binary does not support ARM64. WSL, Bash, curl, CA certificates, and a writable Linux home are prerequisites; enabling WSL may require administrator access and a reboot. Do not silently run elevated system setup.

From PowerShell, run `scripts/install.ps1` from this skill's directory. Resolve that path yourself. Do not ask the user where it is.

```powershell
& '.\scripts\install.ps1' -Distribution Ubuntu-24.04
```

Use `-Component cli` for only the base CLI, or `-Component compose` or `-Component turbo` for a task that needs only that extension and the base CLI. The script forwards the installer's exit code; a missing distribution or unsupported binary is a failure, not a successful partial installation. A script execution policy imposed by the environment remains a prerequisite; do not bypass it.

For each subsequent tool call, select the same distribution and restore the Linux PATH:

```powershell
wsl.exe --distribution Ubuntu-24.04 --exec bash -ec 'export PATH="$HOME/.local/bin:$HOME/.goldsky/bin:$PATH"; goldsky --version; goldsky compose --version; goldsky turbo --version'
if ($LASTEXITCODE -ne 0) { throw 'Goldsky verification failed' }
```

Check each required command's exit status separately when diagnosing a failure; do not treat the last successful command as proof of the preceding ones. Run `goldsky login` yourself in that same WSL distribution, with the PATH above, and leave it running. Logging in through a native Windows installation does not authenticate the Linux installation.

If the agent already runs inside WSL, use `bash scripts/install.sh` from this skill directly. A native PowerShell session without WSL cannot currently install the complete toolset; report the missing prerequisite instead of claiming system-wide support.
