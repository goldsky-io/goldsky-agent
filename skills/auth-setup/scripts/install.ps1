param(
    [string]$Distribution = 'Ubuntu-24.04',
    [string]$User,
    [ValidateSet('all', 'cli', 'compose', 'turbo')]
    [string]$Component = 'all'
)

$ErrorActionPreference = 'Stop'
if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
    throw 'The complete Goldsky toolset requires WSL on Windows. Compose has no native Windows binary. Configure WSL first; enabling it can require administrator access and a reboot.'
}

$WslArguments = @('--distribution', $Distribution)
if ($User) { $WslArguments += @('--user', $User) }

$Installer = Join-Path $PSScriptRoot 'install.sh'
$LinuxInstaller = & wsl.exe @WslArguments --exec wslpath -a $Installer
if ($LASTEXITCODE -ne 0) {
    throw "Could not access the installer in WSL distribution '$Distribution'. Use an installed, initialized distribution and keep subsequent CLI commands and login in that distribution."
}

$LinuxInstaller = "$LinuxInstaller".Trim()
& wsl.exe @WslArguments --exec bash $LinuxInstaller $Component
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
Write-Host "Run subsequent Goldsky commands and manual login inside WSL distribution '$Distribution'."
