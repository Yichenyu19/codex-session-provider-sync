param(
    [string]$InstallDir = $(Join-Path $env:LOCALAPPDATA "CodexSessionProviderSync"),
    [string]$ShortcutName = "Codex Session Provider Sync"
)

$ErrorActionPreference = "Stop"

$Desktop = [Environment]::GetFolderPath("Desktop")
$ShortcutPath = Join-Path $Desktop "$ShortcutName.lnk"

if (Test-Path -LiteralPath $ShortcutPath) {
    Remove-Item -LiteralPath $ShortcutPath -Force
    Write-Host "Removed shortcut: $ShortcutPath"
}

if (Test-Path -LiteralPath $InstallDir) {
    Remove-Item -LiteralPath $InstallDir -Recurse -Force
    Write-Host "Removed install directory: $InstallDir"
}

Write-Host "Uninstalled. Codex data and .codex backups were not removed." -ForegroundColor Green
