# Codex 会话同步器

一个给 Codex Desktop 用的 Windows 小工具。你切换 `model_provider` 之后，点一下就能把本地未归档会话同步回当前供应商，左侧历史不容易“看不见”。

它只同步本机未归档会话元数据，不上传数据，不读取消息正文做网络用，不常驻后台，不注册开机自启。

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

安装后，工具会复制到：

```text
%LOCALAPPDATA%\CodexSessionProviderSync
```

同时创建桌面快捷方式：

```text
Codex 会话同步器
```

## Daily Use

切换 Codex 供应商后，双击桌面快捷方式。PowerShell 窗口会显示目标供应商、更新数量和备份目录。

如果 Codex 正在写状态导致数据库被锁住，关掉 Codex 再点一次就行。

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

卸载只删快捷方式和安装文件，不删 `.codex` 数据和备份。

## Boundaries

- Windows + PowerShell 7 only.
- No tray process.
- No background watcher.
- No startup task.
- No provider credentials are read or uploaded.
- Archived sessions are not changed.
