# Builds and packages the opencode desktop app (electron-vite build +
# electron-builder --dir, i.e. an unpacked win32-x64 build with no
# installer/signing step) and deploys the result over the current local
# install, backing up the previous app.asar first.

$ErrorActionPreference = "Stop"

$BaselineBunDir = "C:\Users\nik\AppData\Local\Microsoft\WinGet\Packages\Oven-sh.Bun.Baseline_Microsoft.Winget.Source_8wekyb3d8bbwe\bun-windows-x64-baseline"
$env:PATH = "$BaselineBunDir;$env:PATH"

# The existing local install is the "prod" channel (OpenCode.exe / ai.opencode.desktop).
# electron-builder.config.ts defaults OPENCODE_CHANNEL to "dev" (OpenCode Dev.exe) when
# unset, which would produce a differently-named binary that wouldn't replace the real one.
$env:OPENCODE_CHANNEL = "prod"

$PackageDir = Split-Path -Parent $PSScriptRoot
Push-Location $PackageDir
try {
    bun run build
    if ($LASTEXITCODE -ne 0) { throw "opencode desktop build failed" }

    bun x electron-builder --win --dir --config electron-builder.config.ts
    if ($LASTEXITCODE -ne 0) { throw "electron-builder packaging failed" }

    $InstallDir = "C:\Users\nik\AppData\Local\Programs\@opencode-aidesktop"
    if (-not (Test-Path $InstallDir)) {
        throw "Desktop app install not found at $InstallDir - install it first (e.g. run the DMG/EXE installer once) before deploying over it"
    }

    $UnpackedDir = Join-Path $PackageDir "dist\win-unpacked"
    if (-not (Test-Path $UnpackedDir)) {
        throw "Packaged output not found at $UnpackedDir"
    }

    $BackupDir = "C:\PROJECTS\_temp\backups"
    New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
    $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $CurrentAsar = Join-Path $InstallDir "resources\app.asar"
    if (Test-Path $CurrentAsar) {
        Copy-Item $CurrentAsar (Join-Path $BackupDir "opencode_desktop_app.asar_backup_$Timestamp") -Force
    }

    # Copy the full unpacked build over the install dir so the Electron
    # runtime stays in sync too, not just the app code. Deliberately NOT
    # /MIR: a --dir build has no NSIS installer, so it lacks "Uninstall
    # OpenCode.exe" and app-update.yml - mirroring would delete those.
    robocopy $UnpackedDir $InstallDir /E /IS /IT /NFL /NDL /NJH /NJS /NC /NS /NP
    if ($LASTEXITCODE -ge 8) { throw "robocopy failed with exit code $LASTEXITCODE" }

    Write-Host "Deployed opencode desktop -> $InstallDir"
}
finally {
    Pop-Location
}
