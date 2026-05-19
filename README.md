# Codex 会话同步器

这是一个给 Codex Desktop 用的 Windows 小工具。你换了 `model_provider` 以后，点它一下，就把本机还在显示的会话同步回来，省得左边历史突然少一截。

它只碰本地会话元数据，不上传数据，不读消息正文，不常驻后台，也不做开机自启。

## 它会做什么

- 读 `%USERPROFILE%\.codex\config.toml` 里的 `model_provider`。
- 只改 `%USERPROFILE%\.codex\state_5.sqlite` 里 `archived = 0` 的线程。
- 顺手把对应 `sessions/**/*.jsonl` 里第一条 `session_meta.payload.model_provider` 也对齐。
- 每次 `apply` 之前都会先备份到 `.codex\session-provider-sync-backups\yyyyMMdd-HHmmss`。
- 如果 Codex 正在占着库，脚本会自己重试几次，不会硬杀进程。

## 怎么安装

在这个目录里打开 PowerShell 7，直接跑：

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1
```

安装完以后，工具会被复制到：

```text
%LOCALAPPDATA%\CodexSessionProviderSync
```

桌面上也会多一个快捷方式：

```text
Codex 会话同步器
```

## 怎么用

以后你只要在切换 Codex 供应商后，双击桌面快捷方式就行。窗口会告诉你现在要对齐到哪个供应商、改了多少、备份放哪了。

如果 Codex 正在写状态，数据库被锁住了，就先关掉 Codex，再点一次。

## 手动命令

先看看，不写入：

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Sync-CodexSessionProvider.ps1 -Mode dry-run
```

真正执行同步：

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Sync-CodexSessionProvider.ps1 -Mode apply
```

恢复最近一次备份：

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Sync-CodexSessionProvider.ps1 -Mode restore
```

如果你的 `.codex` 不在默认位置，可以这样指定：

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Sync-CodexSessionProvider.ps1 -Mode dry-run -CodexHome "D:\path\to\.codex"
```

## 卸载

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\Uninstall.ps1
```

卸载只会删快捷方式和安装文件，不会动 `.codex` 数据和备份。

## 边界

- 只支持 Windows + PowerShell 7。
- 不做托盘，不做后台常驻，不做开机自启。
- 不上传任何会话数据。
- 不改已归档会话。

---

# English

## What it does

- Reads the top-level `model_provider` from `%USERPROFILE%\.codex\config.toml`.
- Updates only unarchived rows in `%USERPROFILE%\.codex\state_5.sqlite`.
- Syncs matching `sessions/**/*.jsonl` first-line `session_meta.payload.model_provider`.
- Backs up before every `apply` under `.codex\session-provider-sync-backups\yyyyMMdd-HHmmss`.
- Retries briefly if Codex is busy and the SQLite database is locked.

## Install

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1
```

It copies the tool to `%LOCALAPPDATA%\CodexSessionProviderSync` and creates a desktop shortcut named `Codex 会话同步器`.

## Usage

After switching providers, double-click the shortcut. The window shows the target provider, update counts, and backup path.

## Manual commands

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Sync-CodexSessionProvider.ps1 -Mode dry-run
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Sync-CodexSessionProvider.ps1 -Mode apply
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Sync-CodexSessionProvider.ps1 -Mode restore
```

## Uninstall

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\Uninstall.ps1
```

It removes the shortcut and installed files, but keeps `.codex` data and backups.
