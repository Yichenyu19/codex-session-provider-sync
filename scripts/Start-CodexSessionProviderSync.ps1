param(
    [switch]$NoPause
)

$ErrorActionPreference = "Stop"
$ScriptPath = Join-Path $PSScriptRoot "Sync-CodexSessionProvider.ps1"

if (-not (Test-Path -LiteralPath $ScriptPath)) {
    Write-Host "Sync script not found: $ScriptPath" -ForegroundColor Red
    if (-not $NoPause) {
        Read-Host "Press Enter to close"
    }
    exit 1
}

& pwsh.exe -NoProfile -ExecutionPolicy Bypass -File $ScriptPath -Mode apply
exit $LASTEXITCODE
