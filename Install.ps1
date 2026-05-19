param(
    [string]$InstallDir = $(Join-Path $env:LOCALAPPDATA "CodexSessionProviderSync"),
    [string]$ShortcutName = "Codex Session Provider Sync"
)

$ErrorActionPreference = "Stop"

try {
    [Console]::InputEncoding = [Text.UTF8Encoding]::new($false)
    [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
} catch {
    # Ignore console encoding setup failures.
}

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "Please run with PowerShell 7:" -ForegroundColor Yellow
    Write-Host "pwsh.exe -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -ForegroundColor Yellow
    exit 1
}

$SourceRoot = Split-Path -Parent $PSCommandPath
$SourceScripts = Join-Path $SourceRoot "scripts"
if (-not (Test-Path -LiteralPath $SourceScripts)) {
    throw "scripts directory not found: $SourceScripts"
}

$InstallScripts = Join-Path $InstallDir "scripts"
New-Item -ItemType Directory -Path $InstallScripts -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $SourceScripts "Sync-CodexSessionProvider.ps1") -Destination $InstallScripts -Force
Copy-Item -LiteralPath (Join-Path $SourceScripts "Start-CodexSessionProviderSync.ps1") -Destination $InstallScripts -Force
Copy-Item -LiteralPath (Join-Path $SourceRoot "Uninstall.ps1") -Destination $InstallDir -Force

$Desktop = [Environment]::GetFolderPath("Desktop")
$ShortcutPath = Join-Path $Desktop "$ShortcutName.lnk"
$StartScript = Join-Path $InstallScripts "Start-CodexSessionProviderSync.ps1"
$Pwsh = (Get-Command "pwsh.exe" -ErrorAction Stop).Source

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($ShortcutPath)
$shortcut.TargetPath = $Pwsh
$shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$StartScript`""
$shortcut.WorkingDirectory = $InstallDir
$shortcut.WindowStyle = 1
$shortcut.Description = "Sync Codex unarchived sessions to the current model_provider."
$shortcut.Save()

Write-Host "Installed Codex Session Provider Sync." -ForegroundColor Green
Write-Host "InstallDir: $InstallDir"
Write-Host "Shortcut: $ShortcutPath"
Write-Host "It does not register startup tasks and does not run in the background."
