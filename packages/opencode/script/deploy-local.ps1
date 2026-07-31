# Builds the opencode CLI for this machine and deploys it over the current
# global npm install (opencode-ai), backing up the previous binary first.
#
# This machine's CPU lacks AVX2, so the standard Bun build panics on launch.
# We prepend the Bun "baseline" (no-AVX2) build to PATH for the whole run so
# every nested `bun x` subprocess uses it too, and we deploy the baseline
# binary as the active `opencode.exe`.

$ErrorActionPreference = "Stop"

$BaselineBunDir = "C:\Users\nik\AppData\Local\Microsoft\WinGet\Packages\Oven-sh.Bun.Baseline_Microsoft.Winget.Source_8wekyb3d8bbwe\bun-windows-x64-baseline"
$env:PATH = "$BaselineBunDir;$env:PATH"

$PackageDir = Split-Path -Parent $PSScriptRoot
Push-Location $PackageDir
try {
    bun run build -- --single --baseline
    if ($LASTEXITCODE -ne 0) { throw "opencode CLI build failed" }

    $NpmRoot = (npm root -g).Trim()
    $InstallDir = Join-Path $NpmRoot "opencode-ai"
    if (-not (Test-Path $InstallDir)) {
        throw "opencode-ai not found under global npm root ($NpmRoot) - install it first with: npm i -g opencode-ai"
    }

    $BackupDir = "C:\PROJECTS\_temp\backups"
    New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
    $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $CurrentExe = Join-Path $InstallDir "bin\opencode.exe"
    if (Test-Path $CurrentExe) {
        Copy-Item $CurrentExe (Join-Path $BackupDir "opencode_backup_$Timestamp.exe") -Force
    }

    $BaselineBin = Join-Path $PackageDir "dist\opencode-windows-x64-baseline\bin\opencode.exe"
    $Avx2Bin = Join-Path $PackageDir "dist\opencode-windows-x64\bin\opencode.exe"

    Copy-Item $BaselineBin $CurrentExe -Force
    Copy-Item $BaselineBin (Join-Path $InstallDir "node_modules\opencode-windows-x64-baseline\bin\opencode.exe") -Force -ErrorAction SilentlyContinue
    if (Test-Path $Avx2Bin) {
        Copy-Item $Avx2Bin (Join-Path $InstallDir "node_modules\opencode-windows-x64\bin\opencode.exe") -Force -ErrorAction SilentlyContinue
    }

    Write-Host "Deployed opencode CLI -> $CurrentExe"
    & opencode --version
}
finally {
    Pop-Location
}
