# Windows Codex: Unable to load organization settings — Troubleshooting Case
# Windows Codex「无法加载组织设置」：完整实测排障记录

> **中文 / English, paragraph by paragraph · 中英文逐节对照**  
> Date / 日期：2026-11-01  
> Outcome / 结果：**Desktop startup recovered. Existing conversations and workspaces remained visible. / 桌面版恢复启动，原有会话与工作区可见。**  
> This is a documented, reversible **case-specific workaround**, not an official universal fix. / 本文是一次可回退的真实修复记录，不是官方通用补丁。

## 1. Symptoms / 故障现象

**中文：** 在 Windows 11 打开 Codex Desktop，出现「无法加载组织设置」（Unable to load organization settings），重试无效，无法进入界面。日志反复出现下列错误。

**English:** Codex Desktop on Windows 11 was stuck at “Unable to load organization settings.” Retry did not help. Startup logs repeatedly reported:

~~~text
Desktop startup policy read failed attempt=1 phase=policy-read reason=protocol retrying=false
~~~

**中文：** 该日志只是协议阶段出错的线索，并不能单独证明网络、账号、CLI 或文件权限是哪一项故障。
**English:** This error class alone does not prove a network, account, CLI, or file-permission root cause.

## 2. Environment / 实际环境

| Item / 项目 | Value / 实测 |
|---|---|
| Windows | Windows 11, build 10.0.26300.9711 |
| App / 应用包 | OpenAI.Codex, AppX/MSIX |
| Desktop version / 桌面版本 | 26.1027.3384.0 |
| AppX status / 安装状态 | Ok |
| Bundled CLI / 内置 CLI | codex-cli 0.166.0-alpha.5.1 |
| WSL | 3.0.3.0; Ubuntu 26.04 LTS, WSL2 |
| Config / 配置 | %USERPROFILE%\.codex\config.toml |
| Logs / 日志 | %LOCALAPPDATA%\Packages\OpenAI.Codex_2p2nqsd0c76g0\LocalCache\Local\Codex\Logs |

All personal paths have been anonymized. / 私人用户名、项目路径和凭据均已脱敏。

## 3. Diagnosis / 排查过程

### 3.1 Check the installation and CLI / 检查安装包和 CLI

**中文：** 安装包状态正常，安装包内的 codex.exe 存在，且版本查询成功。这证明 CLI 可以运行，但不等于整个 Desktop app-server 通信链路正常。

**English:** The installed app was reported healthy and its bundled codex.exe returned a version. That proves the binary launches, but does not validate the desktop app-server protocol.

~~~powershell
$pkg = Get-AppxPackage -Name OpenAI.Codex -ErrorAction SilentlyContinue
$pkg | Select-Object Name, Version, Status, InstallLocation
if ($pkg) {
  $exe = Join-Path $pkg.InstallLocation 'app\resources\codex.exe'
  Write-Host 'CLI exists:' (Test-Path -LiteralPath $exe -PathType Leaf)
  if (Test-Path -LiteralPath $exe -PathType Leaf) { & $exe --version }
}
~~~

Observed / 实测：Status = Ok; CLI exists = True; CLI = 0.166.0-alpha.5.1.

### 3.2 Check CODEX_CLI_PATH / 检查环境变量

**中文：** 用户此前设置过 CODEX_CLI_PATH，但检查时 User、Machine 和 Process 作用域都已为空，而故障仍在。因此，“清理 Windows CLI 覆盖”不是本次最后解决问题的步骤。

**English:** CODEX_CLI_PATH had been set previously, but User, Machine, and Process scopes were empty during testing. The error persisted, so removing that override was not the successful final fix in this case.

~~~powershell
'User','Machine','Process' | ForEach-Object {
  [PSCustomObject]@{
    Scope = $_
    Value = [Environment]::GetEnvironmentVariable('CODEX_CLI_PATH', $_)
  }
}
~~~

**中文：** 注意：config.toml 内 [mcp_servers.node_repl.env] 段落的 CODEX_CLI_PATH 只是 MCP 子进程设置，不等同于 Windows 全局环境变量。
**English:** CODEX_CLI_PATH under [mcp_servers.node_repl.env] is an MCP-local environment setting, not the same as the Windows-wide or user-level override.

### 3.3 Inspect runtimes and logs / 检查 Runtime 和日志

**中文：** 本地 Runtime 目录有两个版本目录；被检测的 CLI 可以运行；.staging-* 目录数量为 0。未发现本案例与 rename_staging / EPERM 直接相关的证据。唯一持续出现的主要错误是 policy-read / protocol。

**English:** The local runtime directory contained two version folders; the checked CLI ran; .staging-* count was zero. This case did not show the decisive rename_staging / EPERM deployment errors seen in some other reports. The repeated relevant failure was policy-read / protocol.

Read-only command / 只读检查命令：

~~~powershell
$logs = Join-Path $env:LOCALAPPDATA 'Packages\OpenAI.Codex_2p2nqsd0c76g0\LocalCache\Local\Codex\Logs'
Get-ChildItem -LiteralPath $logs -Recurse -File -ErrorAction SilentlyContinue |
  Sort-Object LastWriteTime -Descending | Select-Object -First 5 |
  ForEach-Object {
    Write-Host ('--- ' + $_.Name)
    Select-String -LiteralPath $_.FullName -Pattern 'Desktop startup policy read failed|rename_staging|EPERM' |
      Select-Object -Last 12 | ForEach-Object { $_.Line }
  }
~~~

Review logs before sharing publicly: they may contain usernames, paths, or tokens. / 公开日志前先检查是否含有私密信息。

### 3.4 Identify configuration candidates / 找到可疑配置

**中文：** 原始 config.toml 有 notify、integratedTerminalShell = "wsl"、global = "wsl"，以及 node_repl、cua_repl 等 MCP 配置。MCP 里的 CLI 文件实际存在。原始截取未证明 runCodexInWindowsSubsystemForLinux 这一设置是否存在。

**English:** The original config contained notify, integratedTerminalShell = "wsl", global = "wsl", and MCP sections such as node_repl and cua_repl. The MCP CLI file existed. The available excerpt did not establish whether runCodexInWindowsSubsystemForLinux was present.

Illustrative anonymized excerpt / 脱敏示例：

~~~toml
notify = ["C:\\Users\\<USER>\\AppData\\Local\\OpenAI\\Codex\\runtimes\\cua_node\\<HASH>\\bin\\..."]
integratedTerminalShell = "wsl"
global = "wsl"

[mcp_servers.node_repl]
[mcp_servers.node_repl.env]
CODEX_CLI_PATH = 'C:\Users\<USER>\AppData\Local\OpenAI\Codex\bin\<HASH>\codex.exe'

[mcp_servers.cua_repl]
~~~

## 4. Real A/B test / 实际成功与失败的测试

| Modification / 修改 | Actual outcome / 结果 |
|---|---|
| Original config / 原配置 | **FAIL / 无法启动** |
| Temporarily rename entire config.toml / 隔离整个配置 | **PASS / 能启动** |
| Restore original; disable only notify / 仅注释 notify | **FAIL / 仍不能启动** |
| Restore original; disable notify plus WSL startup settings / 同时禁用 notify 和 WSL 启动设置 | **PASS / 能启动** |
| Inspect chats and workspaces / 检查历史记录和项目 | **PASS / 仍可见** |

**中文：** 这是最重要的证据。成功测试同时禁用了若干设置，没有完成单变量对照，不能据此宣称 notify 或某个 WSL 键就是唯一根因。

**English:** This is the critical evidence. The working test changed multiple settings. No controlled one-variable test established notify or any single WSL key as the exclusive root cause.

## 5. Reproducible fix / 可以复用的修复步骤

### Step 1 — Back up and isolate config / 第一步：备份并隔离配置

**中文：** 完全退出 Codex。只备份、重命名 config.toml，不删除整个 .codex 目录。再启动 Codex 测试。

**English:** Fully close Codex. Back up and rename only config.toml, not the whole .codex folder, then try relaunching.

~~~powershell
$cfg = Join-Path $env:USERPROFILE '.codex\config.toml'
if (-not (Test-Path -LiteralPath $cfg -PathType Leaf)) { throw 'config.toml missing' }
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
Copy-Item -LiteralPath $cfg -Destination "$cfg.backup-$stamp" -ErrorAction Stop
Rename-Item -LiteralPath $cfg -NewName "config.toml.disabled-$stamp" -ErrorAction Stop
Write-Host 'Restart Codex / 请重新打开 Codex'
~~~

**Observed result / 结果：** Codex launched successfully / 正常启动。

### Step 2 — Restore selectively / 第二步：选择性恢复配置

**中文：** 从之前保留的原始 config.toml 恢复设置，保留 MCP 等其他配置，只注释匹配的单行 notify 和 WSL 启动设置。仓库附带的 fix 脚本会在修改前再创建备份，并且支持 -WhatIf。建议先预演。

**English:** Start from the original config, preserve unrelated settings (including MCP), and comment only matching one-line notify and WSL startup entries. The repository's helper creates a timestamped backup and supports -WhatIf.

~~~powershell
# Run from the repository root, after fully quitting Codex
.\scripts\fix-codex-config.ps1 -WhatIf
.\scripts\fix-codex-config.ps1
~~~

Targeted keys / 目标配置：
~~~toml
# notify = [...]
# integratedTerminalShell = "wsl"
# global = "wsl"
# runCodexInWindowsSubsystemForLinux = true   # ONLY if this key exists
~~~

**中文：** 最后一行仅在实际配置存在且值为 true 时才会被注释，不能假设每个版本都有这个选项。操作不会修改 Ubuntu 虚拟磁盘。修改之后重新打开 Codex，检查历史对话与工作区，再完全关闭重新启动一次，确认是否复发。

**English:** The last line is only touched if it actually exists with a true value. This action does not modify the Ubuntu VHDX. Relaunch, check conversations/workspaces, and do another cold restart to test recurrence.

### Step 3 — Roll back if needed / 第三步：必要时回退

**中文：** 回退脚本需要明确指定备份路径，会先保存当前配置再恢复选定备份。注意恢复旧的故障配置也可能使 Codex 再次无法启动。

**English:** Rollback requires an explicit backup path and first saves the current config. Restoring an old broken config can restore the bug.

~~~powershell
.\scripts\restore-config.ps1 -BackupPath "$env:USERPROFILE\.codex\config.toml.backup-YYYYMMDD-HHMMSS" -WhatIf
.\scripts\restore-config.ps1 -BackupPath "$env:USERPROFILE\.codex\config.toml.backup-YYYYMMDD-HHMMSS"
~~~

### Avoid destructive actions / 不建议直接进行的操作

**中文：** 不要优先清空 .codex 目录、重装 Windows、卸载 WSL、运行 wsl --unregister、修改 ext4.vhdx 权限，或清理尚未提交的 Git 结果。它们与本次已验证的修复步骤无关。

**English:** Do not begin with deleting the .codex folder, reinstalling Windows, unregistering WSL, changing VHDX ACLs, or cleaning uncommitted Git files. None was necessary for the confirmed recovery.

## 6. Interpretation and limits / 原因分析与局限

**中文：** 本案可以确认：配置文件参与了失败路径，且同时禁用 notify 和 WSL 启动设置后能够启动。不能确认：究竟是哪一个具体设置导致、是否存在 app-server 字段级协议不兼容、不同模型是否会改变 Windows 沙箱权限。

**English:** Established: the original config was involved and the combined workaround enabled startup. Not established: the unique failing key, the precise app-server protocol mismatch, or any model-dependent sandbox privilege mechanism.

**中文：** 其他用户也报告了相同提示，但可能分别由过期 CODEX_CLI_PATH、Runtime 部署失败、notify 或 WSL 初始化造成，所以应以日志与对照试验为准。

**English:** Other users have seen the same dialog for different reasons: stale CODEX_CLI_PATH overrides, runtime deployment failures, notify settings, or WSL agent initialization. Match your own evidence before applying a workaround.

## 7. Follow-up only: Codex could not invoke Ubuntu / 后续补充：Codex 内无法调用 Ubuntu

**中文：** 桌面版恢复后，Codex Windows 执行环境中曾遇到以下错误；而在普通 Windows PowerShell 中，WSL 能成功启动并访问已有 Git 工程。这说明不能因为 Codex 内部报错就断定 Ubuntu 的 ext4.vhdx 已损坏。

**English:** After desktop startup was restored, Codex's Windows execution context sometimes failed to mount WSL, while an ordinary PowerShell session launched the same Ubuntu successfully and accessed its existing Git repository. This does not establish disk corruption.

~~~text
Wsl/Service/CreateInstance/MountDisk/HCS/E_ACCESSDENIED
~~~

~~~powershell
wsl -d Ubuntu --exec whoami
# Observed / 实测: exit code 0 / 退出码 0
~~~

**中文：** 后来切换 Codex 模型/执行方式后可以进入 Ubuntu，但没有记录完整的命令与授权对照，不能据此证明某个模型本身修好了 WSL。此问题不作为本文主要主题；详见 [附录 / follow-up](docs/wsl-access-followup.md)。

**English:** Ubuntu later became accessible after changing the Codex model/execution context, but a controlled comparison of commands and permissions was not captured. The model name is not a proven root cause. This is a secondary topic; see [the follow-up](docs/wsl-access-followup.md).

## 8. Reference reports / 其他已公开的类似案例

These links describe distinct cases; they do not prove our unique root cause. / 以下是其他人的案例，不是本案例根因的证明。

- [openai/codex #48324](https://github.com/openai/codex/issues/48324) — Startup dialog; comments discuss config, notify and WSL agent environment.
- [openai/codex #54478](https://github.com/openai/codex/issues/54478) — WSL agent environment with startup policy dialog.
- [openai/codex #57051](https://github.com/openai/codex/issues/57051) — Stale user CODEX_CLI_PATH override (different fix).
- [openai/codex #57005](https://github.com/openai/codex/issues/57005) — rename_staging / EPERM runtime-deployment failure (different fix).
- [openai/codex #21470](https://github.com/openai/codex/issues/21470) — WSL access denied within Windows Codex sandbox, but works outside.

---

**Takeaway / 核心经验：** **Back up → check logs → isolate config → selectively restore → verify. / 先备份 → 看日志 → 隔离配置 → 逐项恢复 → 验证结果。**

*Community troubleshooting notes; not an official OpenAI release. / 社区技术经验记录，不是 OpenAI 官方发布的通用修复。*
