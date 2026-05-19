param(
    [ValidateSet("dry-run", "apply", "restore")]
    [string]$Mode = "dry-run",
    [string]$CodexHome = $(if (-not [string]::IsNullOrWhiteSpace($env:CODEX_HOME)) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE ".codex" }),
    [string]$BackupRoot = $(if (-not [string]::IsNullOrWhiteSpace($env:CODEX_PROVIDER_SYNC_BACKUP_ROOT)) { $env:CODEX_PROVIDER_SYNC_BACKUP_ROOT } else { $null }),
    [string]$RestoreFrom = $null,
    [int]$MaxAttempts = 8,
    [int]$RetryDelayMs = 750,
    [switch]$NoPause
)

$ErrorActionPreference = "Stop"

try {
    [Console]::InputEncoding = [Text.UTF8Encoding]::new($false)
    [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
} catch {
    # Ignore console encoding setup failures.
}

function Assert-PowerShell7 {
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        throw "Please run this script with PowerShell 7: pwsh.exe -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    }
}

function Resolve-RequiredPath {
    param(
        [string]$Path,
        [string]$Label
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "$Label is empty."
    }
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "$Label does not exist: $Path"
    }
    return (Resolve-Path -LiteralPath $Path).Path
}

function Get-CurrentProvider {
    param([string]$ConfigPath)

    $content = Get-Content -LiteralPath $ConfigPath -Raw
    $match = [regex]::Match($content, '(?m)^\s*model_provider\s*=\s*"([^"]+)"\s*$')
    if (-not $match.Success) {
        throw "Cannot read top-level model_provider from config.toml: $ConfigPath"
    }
    return $match.Groups[1].Value
}

function Invoke-WithRetry {
    param(
        [scriptblock]$Action,
        [int]$Attempts,
        [int]$DelayMs
    )

    $lastError = $null
    for ($index = 1; $index -le $Attempts; $index++) {
        try {
            return & $Action
        } catch {
            $lastError = $_
            $message = $_.Exception.Message
            $isLock = $message -match "database is locked|locked|busy|unable to open database file"
            if (-not $isLock -or $index -eq $Attempts) {
                break
            }
            Write-Host ("Codex state is busy, retrying {0}/{1}..." -f $index, $Attempts) -ForegroundColor Yellow
            Start-Sleep -Milliseconds $DelayMs
        }
    }
    throw $lastError
}

function Invoke-PythonJson {
    param(
        [string]$Code,
        [hashtable]$Env
    )

    foreach ($key in $Env.Keys) {
        [Environment]::SetEnvironmentVariable($key, [string]$Env[$key], "Process")
    }
    $json = $Code | python -
    if ($LASTEXITCODE -ne 0) {
        throw "Python helper failed with exit code $LASTEXITCODE"
    }
    return $json | ConvertFrom-Json
}

function Invoke-ProviderScan {
    param(
        [string]$CodexHome,
        [string]$TargetProvider
    )

    $python = @'
import json
import os
import pathlib
import sqlite3

codex_home = pathlib.Path(os.environ["CODEX_HOME"])
target_provider = os.environ["TARGET_PROVIDER"]
db_path = codex_home / "state_5.sqlite"
session_root = codex_home / "sessions"

result = {
    "targetProvider": target_provider,
    "dbPath": str(db_path),
    "threadsToUpdate": [],
    "sessionFilesToUpdate": [],
    "sessionFilesScanned": 0,
}

if not db_path.exists():
    print(json.dumps(result, ensure_ascii=False))
    raise SystemExit(0)

conn = sqlite3.connect(db_path, timeout=8)
conn.execute("PRAGMA busy_timeout = 8000")
conn.row_factory = sqlite3.Row
rows = conn.execute(
    "SELECT id, title, cwd, archived, model_provider FROM threads WHERE archived = 0 AND COALESCE(model_provider, '') <> ? ORDER BY updated_at_ms DESC",
    (target_provider,),
).fetchall()
result["threadsToUpdate"] = [dict(row) for row in rows]
thread_map = {row["id"]: row for row in rows}
conn.close()

if session_root.exists():
    for path in session_root.rglob("*.jsonl"):
        result["sessionFilesScanned"] += 1
        try:
            raw = path.read_text(encoding="utf-8")
        except Exception:
            continue
        if not raw.strip():
            continue
        try:
            meta = json.loads(raw.splitlines()[0])
        except Exception:
            continue
        payload = meta.get("payload")
        if not isinstance(payload, dict):
            continue
        thread_id = payload.get("id")
        if thread_id not in thread_map:
            continue
        if (payload.get("model_provider") or "") == target_provider:
            continue
        result["sessionFilesToUpdate"].append({
            "path": str(path),
            "relativePath": path.relative_to(codex_home).as_posix(),
            "threadId": thread_id,
            "currentProvider": payload.get("model_provider"),
        })

print(json.dumps(result, ensure_ascii=False))
'@

    return Invoke-PythonJson -Code $python -Env @{
        CODEX_HOME = $CodexHome
        TARGET_PROVIDER = $TargetProvider
    }
}

function New-BackupSnapshot {
    param(
        [string]$CodexHome,
        [string]$BackupRoot,
        [object]$Scan
    )

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupDir = Join-Path $BackupRoot $timestamp
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

    $files = New-Object System.Collections.Generic.List[string]
    foreach ($name in @("state_5.sqlite", "state_5.sqlite-wal", "state_5.sqlite-shm")) {
        $source = Join-Path $CodexHome $name
        if (Test-Path -LiteralPath $source) {
            Copy-Item -LiteralPath $source -Destination (Join-Path $backupDir $name) -Force
            $files.Add($name) | Out-Null
        }
    }

    foreach ($item in @($Scan.sessionFilesToUpdate)) {
        $sourcePath = [string]$item.path
        if (-not (Test-Path -LiteralPath $sourcePath)) {
            continue
        }
        $relativePath = [string]$item.relativePath
        $targetPath = Join-Path $backupDir $relativePath
        $targetFolder = Split-Path -Parent $targetPath
        New-Item -ItemType Directory -Path $targetFolder -Force | Out-Null
        Copy-Item -LiteralPath $sourcePath -Destination $targetPath -Force
        $files.Add($relativePath) | Out-Null
    }

    [pscustomobject]@{
        createdAt = (Get-Date).ToString("o")
        codexHome = $CodexHome
        targetProvider = $Scan.targetProvider
        threadCount = @($Scan.threadsToUpdate).Count
        sessionFileCount = @($Scan.sessionFilesToUpdate).Count
        backedUpFiles = $files
    } | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $backupDir "manifest.json") -Encoding UTF8

    return $backupDir
}

function Invoke-ProviderApply {
    param(
        [string]$CodexHome,
        [string]$TargetProvider
    )

    $python = @'
import json
import os
import pathlib
import sqlite3

codex_home = pathlib.Path(os.environ["CODEX_HOME"])
target_provider = os.environ["TARGET_PROVIDER"]
db_path = codex_home / "state_5.sqlite"
session_root = codex_home / "sessions"

summary = {
    "dbUpdated": 0,
    "sessionFilesUpdated": 0,
    "sessionFilesSkipped": 0,
}

if not db_path.exists():
    print(json.dumps(summary, ensure_ascii=False))
    raise SystemExit(0)

conn = sqlite3.connect(db_path, timeout=8)
conn.execute("PRAGMA busy_timeout = 8000")
conn.row_factory = sqlite3.Row
conn.execute("BEGIN IMMEDIATE")
rows = conn.execute(
    "SELECT id FROM threads WHERE archived = 0 AND COALESCE(model_provider, '') <> ?",
    (target_provider,),
).fetchall()
thread_ids = {row["id"] for row in rows}
if thread_ids:
    before = conn.total_changes
    conn.execute(
        "UPDATE threads SET model_provider = ? WHERE archived = 0 AND COALESCE(model_provider, '') <> ?",
        (target_provider, target_provider),
    )
    summary["dbUpdated"] = conn.total_changes - before
conn.commit()
conn.close()

if session_root.exists():
    for path in session_root.rglob("*.jsonl"):
        try:
            raw = path.read_text(encoding="utf-8")
        except Exception:
            summary["sessionFilesSkipped"] += 1
            continue
        if not raw.strip():
            summary["sessionFilesSkipped"] += 1
            continue
        lines = raw.splitlines()
        try:
            meta = json.loads(lines[0])
        except Exception:
            summary["sessionFilesSkipped"] += 1
            continue
        payload = meta.get("payload")
        if not isinstance(payload, dict):
            summary["sessionFilesSkipped"] += 1
            continue
        thread_id = payload.get("id")
        if thread_id not in thread_ids:
            summary["sessionFilesSkipped"] += 1
            continue
        if (payload.get("model_provider") or "") == target_provider:
            summary["sessionFilesSkipped"] += 1
            continue
        payload["model_provider"] = target_provider
        lines[0] = json.dumps(meta, ensure_ascii=False, separators=(",", ":"))
        newline = "\r\n" if "\r\n" in raw else "\n"
        text = newline.join(lines)
        if raw.endswith(("\n", "\r")):
            text += newline
        path.write_text(text, encoding="utf-8")
        summary["sessionFilesUpdated"] += 1

print(json.dumps(summary, ensure_ascii=False))
'@

    return Invoke-PythonJson -Code $python -Env @{
        CODEX_HOME = $CodexHome
        TARGET_PROVIDER = $TargetProvider
    }
}

function Restore-ProviderBackup {
    param(
        [string]$CodexHome,
        [string]$BackupDir
    )

    if (-not (Test-Path -LiteralPath $BackupDir)) {
        throw "Backup directory does not exist: $BackupDir"
    }

    $restored = New-Object System.Collections.Generic.List[string]
    foreach ($name in @("state_5.sqlite", "state_5.sqlite-wal", "state_5.sqlite-shm")) {
        $source = Join-Path $BackupDir $name
        if (Test-Path -LiteralPath $source) {
            Copy-Item -LiteralPath $source -Destination (Join-Path $CodexHome $name) -Force
            $restored.Add($name) | Out-Null
        }
    }

    foreach ($path in Get-ChildItem -LiteralPath $BackupDir -Recurse -File -Filter "*.jsonl") {
        $relative = [System.IO.Path]::GetRelativePath($BackupDir, $path.FullName)
        $target = Join-Path $CodexHome $relative
        New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
        Copy-Item -LiteralPath $path.FullName -Destination $target -Force
        $restored.Add($relative) | Out-Null
    }

    return $restored
}

function Write-Summary {
    param($Object)
    $Object | ConvertTo-Json -Depth 12
}

try {
    Assert-PowerShell7
    $CodexHome = Resolve-RequiredPath -Path $CodexHome -Label "CodexHome"
    $ConfigPath = Resolve-RequiredPath -Path (Join-Path $CodexHome "config.toml") -Label "config.toml"
    $BackupRoot = if ([string]::IsNullOrWhiteSpace($BackupRoot)) { Join-Path $CodexHome "session-provider-sync-backups" } else { $BackupRoot }
    New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null
    $TargetProvider = Get-CurrentProvider -ConfigPath $ConfigPath

    if ($Mode -eq "restore") {
        if ([string]::IsNullOrWhiteSpace($RestoreFrom)) {
            $latest = Get-ChildItem -LiteralPath $BackupRoot -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if (-not $latest) {
                throw "No backup found under: $BackupRoot"
            }
            $RestoreFrom = $latest.FullName
        }
        $restored = Restore-ProviderBackup -CodexHome $CodexHome -BackupDir $RestoreFrom
        Write-Summary ([pscustomobject]@{
            mode = "restore"
            codexHome = $CodexHome
            restoredFrom = $RestoreFrom
            restoredFiles = @($restored).Count
        })
        return
    }

    $scan = Invoke-WithRetry -Attempts $MaxAttempts -DelayMs $RetryDelayMs -Action {
        Invoke-ProviderScan -CodexHome $CodexHome -TargetProvider $TargetProvider
    }

    if ($Mode -eq "dry-run") {
        Write-Summary ([pscustomobject]@{
            mode = "dry-run"
            codexHome = $CodexHome
            targetProvider = $TargetProvider
            unarchivedThreadCount = @($scan.threadsToUpdate).Count
            sessionFileCount = @($scan.sessionFilesToUpdate).Count
            sessionFilesScanned = $scan.sessionFilesScanned
            sampleThreads = @($scan.threadsToUpdate | Select-Object -First 5)
        })
        return
    }

    $backupDir = New-BackupSnapshot -CodexHome $CodexHome -BackupRoot $BackupRoot -Scan $scan
    $apply = Invoke-WithRetry -Attempts $MaxAttempts -DelayMs $RetryDelayMs -Action {
        Invoke-ProviderApply -CodexHome $CodexHome -TargetProvider $TargetProvider
    }

    Write-Summary ([pscustomobject]@{
        mode = "apply"
        codexHome = $CodexHome
        targetProvider = $TargetProvider
        backupDir = $backupDir
        unarchivedThreadCount = @($scan.threadsToUpdate).Count
        sessionFileCount = @($scan.sessionFilesToUpdate).Count
        dbUpdated = $apply.dbUpdated
        sessionFilesUpdated = $apply.sessionFilesUpdated
        sessionFilesSkipped = $apply.sessionFilesSkipped
    })
} catch {
    Write-Host ""
    Write-Host "Codex Session Provider Sync failed:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    Write-Host "If Codex is open and actively writing state, close Codex and run the shortcut again." -ForegroundColor Yellow
    exit 1
} finally {
    if (-not $NoPause) {
        Write-Host ""
        Read-Host "Press Enter to close"
    }
}
