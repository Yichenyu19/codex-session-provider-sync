# codex-session-provider-sync

One-click Windows helper for Codex Desktop users who switch `model_provider` often and then find local conversations missing from the left sidebar.

It syncs unarchived local session metadata to the current provider in `%USERPROFILE%\.codex\config.toml`. It does not upload data, does not read message bodies for network use, does not run in the background, and does not register startup tasks.

## What It Does

- Reads the current top-level `model_provider` from `%USERPROFILE%\.codex\config.toml`.
- Updates only unarchived rows in `%USERPROFILE%\.codex\state_5.sqlite`.
- Updates matching `sessions/**/*.jsonl` first-line `session_meta.payload.model_provider`.
- Creates a backup before every `apply` under `.codex\session-provider-sync-backups\yyyyMMdd-HHmmss`.
- Retries briefly if Codex is open and the SQLite database is busy.

## Install

Open PowerShell 7 in this folder, then run:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1
```

The installer copies the tool to:

```text
%LOCALAPPDATA%\CodexSessionProviderSync
```

It also creates a desktop shortcut:

```text
Codex Session Provider Sync
```

## Daily Use

After switching Codex provider, double-click the desktop shortcut. A PowerShell window will show the target provider, updated thread count, updated session file count, and backup directory.

If Codex is actively writing state and the database stays locked, close Codex and click the shortcut again.

## Manual Commands

Preview without writing:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Sync-CodexSessionProvider.ps1 -Mode dry-run
```

Apply sync:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Sync-CodexSessionProvider.ps1 -Mode apply
```

Restore the latest backup:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Sync-CodexSessionProvider.ps1 -Mode restore
```

Use a custom Codex home:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Sync-CodexSessionProvider.ps1 -Mode dry-run -CodexHome "D:\path\to\.codex"
```

## Uninstall

From the installed directory or the downloaded project folder:

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\Uninstall.ps1
```

Uninstall removes the desktop shortcut and installed tool files. It does not remove `.codex` data or backups.

## Boundaries

- Windows + PowerShell 7 only.
- No tray process.
- No background watcher.
- No startup task.
- No provider credentials are read or uploaded.
- Archived sessions are not changed.
