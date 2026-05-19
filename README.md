# Codex 会话同步器

给 Codex Desktop 用的 Windows 小工具。你切换 `model_provider` 以后，点一下它，就能把本机未归档会话同步回当前供应商，尽量避免左边历史“看不见”。

它只处理本地会话元数据，不上传数据，不读取消息正文做网络发送，不常驻后台，不注册开机自启。

## 这东西能干嘛

- 读取 `%USERPROFILE%\.codex\config.toml` 里的顶层 `model_provider`。
- 只更新 `%USERPROFILE%\.codex\state_5.sqlite` 里 `archived = 0` 的线程。
- 同步对应 `sessions/**/*.jsonl` 的首条 `session_meta.payload.model_provider`。
- 每次执行 `apply` 前自动备份到 `.codex\session-provider-sync-backups\yyyyMMdd-HHmmss`。
- 如果 Codex 正在写状态，脚本会短暂重试，不会强杀进程。

## 安装

在这个文件夹里打开 PowerShell 7，运行：

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1
```

安装后，工具会复制到：

```text
%LOCALAPPDATA%\CodexSessionProviderSync
```

同时会创建桌面快捷方式：

```text
Codex 会话同步器
```

## 怎么用

切换 Codex 供应商后，双击桌面快捷方式。窗口会显示目标供应商、更新数量和备份目录。

如果 Codex 正在写状态导致数据库被锁住，先关掉 Codex，再点一次快捷方式。

## 手动命令

预览，不写入：

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Sync-CodexSessionProvider.ps1 -Mode dry-run
```

执行同步：

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Sync-CodexSessionProvider.ps1 -Mode apply
```

恢复最近一次备份：

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Sync-CodexSessionProvider.ps1 -Mode restore
```

指定自己的 `.codex` 目录：

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Sync-CodexSessionProvider.ps1 -Mode dry-run -CodexHome "D:\path\to\.codex"
```

## 卸载

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\Uninstall.ps1
```

卸载只删快捷方式和安装文件，不删 `.codex` 数据和备份。

## 边界

- 只支持 Windows + PowerShell 7。
- 不做托盘。
- 不做后台常驻。
- 不做开机自启。
- 不上传任何会话数据。
- 不修改已归档会话。

---

# English

## What it does

- Reads the top-level `model_provider` from `%USERPROFILE%\.codex\config.toml`.
- Updates only unarchived rows in `%USERPROFILE%\.codex\state_5.sqlite`.
- Updates matching `sessions/**/*.jsonl` first-line `session_meta.payload.model_provider`.
- Creates a backup before every `apply` under `.codex\session-provider-sync-backups\yyyyMMdd-HHmmss`.
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
