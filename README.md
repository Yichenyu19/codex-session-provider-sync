# Codex 会话同步器

> 换了 Codex 的 `model_provider` 之后，点一下桌面快捷方式，把还在左边显示的未归档会话同步回来。

这是一个 Windows 小工具，不是常驻应用，也不是后台服务。它只做一件事：把本地 Codex 的会话元数据对齐到当前供应商，尽量别让历史突然“看不见”。

## 快速开始

### 安装

在仓库目录里打开 PowerShell 7，运行：

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1
```

安装后，工具会放到：

```text
%LOCALAPPDATA%\CodexSessionProviderSync
```

同时会在桌面创建快捷方式：

```text
Codex 会话同步器
```

### 使用

以后你只要在切换 Codex 供应商后，双击桌面快捷方式就行。窗口会告诉你当前对齐到哪个供应商、改了多少、备份放哪了。

如果 Codex 正在写状态，把数据库占住了，先关掉 Codex，再点一次。

### 手动运行

先预览，不写入：

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

如果你的 `.codex` 不在默认位置，可以自己指定：

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Sync-CodexSessionProvider.ps1 -Mode dry-run -CodexHome "D:\path\to\.codex"
```

### 这个工具到底干了什么

- 读 `%USERPROFILE%\.codex\config.toml` 里的当前 `model_provider`。
- 只同步 `%USERPROFILE%\.codex\state_5.sqlite` 里 `archived = 0` 的线程。
- 顺手把对应 `sessions/**/*.jsonl` 的首条 `session_meta.payload.model_provider` 也改一致。
- 每次 `apply` 前都会自动备份，出问题可以回滚。
- 如果 Codex 正在占库，脚本会自己重试，不会强杀进程。

## 卸载

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\Uninstall.ps1
```

它只会删快捷方式和安装文件，不会动 `.codex` 数据和备份。

## 注意

- 只支持 Windows + PowerShell 7。
- 不做托盘，不做后台常驻，不做开机自启。
- 不上传任何会话数据。
- 不改已归档会话。

## English

### What it is

Codex Session Provider Sync is a small Windows helper for Codex Desktop. When you switch providers, click once and sync the unarchived local sessions back to the current `model_provider`.

It is not a background app. It does not upload data, it does not read message bodies for network use, and it does not register startup tasks.

### What it does

- Reads the current `model_provider` from `%USERPROFILE%\.codex\config.toml`.
- Updates only unarchived rows in `%USERPROFILE%\.codex\state_5.sqlite`.
- Syncs the first `session_meta.payload.model_provider` inside matching `sessions/**/*.jsonl` files.
- Creates a backup before every `apply`.
- Retries briefly when Codex is holding the database lock.

### Install

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\Install.ps1
```

### Use

After switching providers, double-click the desktop shortcut.

### Uninstall

```powershell
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\Uninstall.ps1
```
