# WSL access follow-up / Codex 访问 WSL 的后续记录

This is **not** the main organization-settings issue. / 这不是「无法加载组织设置」的主问题。

## Observation / 现象

Codex's Windows execution context once returned / Codex Windows 执行环境出现：

~~~text
Wsl/Service/CreateInstance/MountDisk/HCS/E_ACCESSDENIED
~~~

But direct Windows PowerShell commands succeeded / 普通 PowerShell 则可成功执行：

~~~powershell
wsl -d Ubuntu --exec whoami
wsl -d Ubuntu --exec cat /etc/os-release
~~~

**Observed / 实测：** exit code 0; Ubuntu 26.04 LTS, project directory and Git repository accessible. / 退出码 0、Ubuntu 26.04 LTS、工程及 Git 仓库可访问。

## Interpretation / 判断

**中文：** 这说明不能直接认定 ext4.vhdx 已损坏。不同 Codex 执行环境、授权上下文或沙箱策略可能影响是否能调用 WSL。之后切换模型或执行方式成功进入 WSL，但缺少控制变量和授权记录，不能证明模型本身修复了权限。

**English:** The evidence does not establish a corrupt VHDX. Execution context, permissions or sandbox policy could explain why launching WSL inside Codex differed from launching it in PowerShell. Later success after a model/execution-method change does not prove that model choice itself fixed permissions.

The localhost proxy/NAT warning was independent and did not stop the direct test. / localhost 代理警告是独立事项，并未阻止该只读测试。

Avoid deleting WSL distributions or changing VHDX ACLs without evidence. / 没有证据时不要删除 WSL 发行版或修改 VHDX ACL。
