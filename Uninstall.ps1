param(
    [string]$InstallDir = $(Join-Path $env:LOCALAPPDATA "CodexSessionProviderSync"),
    [string]$ShortcutName = "Codex 会话同步器"
)

$ErrorActionPreference = "Stop"

$Desktop = [Environment]::GetFolderPath("Desktop")
$ShortcutPath = Join-Path $Desktop "$ShortcutName.lnk"

if (Test-Path -LiteralPath $ShortcutPath) {
    Remove-Item -LiteralPath $ShortcutPath -Force
    Write-Host "已删除快捷方式: $ShortcutPath"
}

if (Test-Path -LiteralPath $InstallDir) {
    Remove-Item -LiteralPath $InstallDir -Recurse -Force
    Write-Host "已删除安装目录: $InstallDir"
}

Write-Host "卸载完成，未删除 Codex 数据和 .codex 备份。" -ForegroundColor Green
