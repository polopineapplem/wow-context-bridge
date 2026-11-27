# 安装运行与跨电脑接续

## 另一台电脑开始工作

登录有权访问私有仓库的 GitHub 账号，clone 或下载仓库。让新会话先读 AGENTS.md、START_HERE 和 HANDOFF。GitHub 认证、游戏安装和运行中的读者都不会随仓库自动迁移。

只继续开发时不需要游戏；测试使用 Python/lupa 和 PowerShell。需要实际角色数据时，必须在能访问游戏日志的 Windows 电脑运行读者。不要把原电脑的 D 盘目录、PID 或程序运行状态当成新电脑事实。

## 在游戏电脑运行

用户安装步骤见 [INSTALL.zh-CN.md](../INSTALL.zh-CN.md)（英文版 [INSTALL.md](../INSTALL.md)）。`start.bat` 会自动查找游戏目录（注册表里的 Blizzard 安装路径，以及各固定磁盘下常见的 `World of Warcraft\_forever_` 位置）。找不到或找到多个时，用：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\start.ps1 -GameRoot 'E:\Games\World of Warcraft\_forever_'
```

这里的路径只是示例，应由执行工作的 agent 找到实际目录，不要求用户复制粘贴。脚本运行策略只用于该进程，没有永久修改系统执行策略。

插件首次安装时若游戏已经打开，要正常退出重开再登录。更改已加载插件代码后，不能把磁盘文件修改视为已生效；在用户允许的正常游戏加载周期验证，不自动发送游戏输入。

前台运行时 Ctrl+C 停止读者。后台启动要隐藏窗口、记录实际命令行和输出位置。当前没有随仓库提供自动后台管理或系统服务；旧会话后台进程只是现场启动实例。

## 参数

| 参数 | 用途 |
| --- | --- |
| GameRoot | 包含 Wow.exe 的 `_forever_` 目录；不填时自动查找，唯一结果才自动使用 |
| SkipInstall | 不复制插件，仅启动读者；后台测试曾使用此项 |
| Once | 读取当前日志一次，不持续轮询 |
| LogPath | 覆盖日志位置，用于测试或单独解析 |
| OutputPath | 覆盖 JSON 路径；默认脚本目录 player.json |
| HistoryPath | 变化历史；默认 OutputPath 同目录 history.jsonl |
| HistoryLimit | 保留的历史行数，默认 500 |
| BootstrapWindow | 启动扫描初始窗口，默认 2MB |
| Iterations | 测试用：轮询次数后退出 |

OutputPath 的父目录应已存在。不要让模拟测试写入真实 player.json，也不要同时从多个 checkout 启动针对同一游戏的不同输出读者而不做记录。

## 故障定位

| 现象 | 排查顺序 |
| --- | --- |
| waiting_for_game | 游戏是否重新加载新插件；插件目录/版本是否正确；日志是否存在及包含 LCB1；是否真的登录角色 |
| 文件不再刷新 | 核实读者进程、命令行、错误输出；旧 PID 可能已被复用 |
| snapshot_received 但 stale | 检查 capturedAt；战斗/离线/传输停止/时钟异常均可能；不要伪改时间 |
| 重启后先看到旧数据 | 启动只发布最新完整快照；若仍旧，检查 capturedAt 和游戏是否在发送 |
| 不确定哪一步坏了 | 运行 `check-setup.bat`（只读检查；`-Json` 给 AI 用） |
| AI 说读者未运行 | MCP 的 readerLikelyRunning=false：重新运行 start.bat |
| 客户端里看不到 wow-context | 是否运行过 install-mcp.bat；是否完全退出并重开客户端；Microsoft Store 版 Claude 的配置在 `%LOCALAPPDATA%\Packages\Claude_*\LocalCache\Roaming\Claude`，脚本会自动找；配置出错可用 `.bak` 还原 |
| 任务不足 | 检查折叠标记与 capabilities/errors；尚无可靠自动修复 |
| 名称缺失 | namePending 可能表示缓存未就绪；后续采样会重试 |
| 没坐标 | 地图 API 可能不支持当前位置，不填零冒充有效坐标 |
| 另一个读者启动后退出 | 同输出路径 Mutex 阻止重复进程；找到真正运行实例 |

排查日志时只筛选专用 LCB1 行及文件元数据，不输出所有私聊。检查进程必要时使用实际 Windows 会话；受限环境枚举不到进程不等于进程不存在。

## 运行开发测试

```powershell
pwsh -NoProfile -File .\test-reader.ps1
python -m pip install lupa==2.8
python .\tests\test_addon.py
python .\tests\test_mcp.py
python .\tests\test_install_mcp.py
python .\tests\test_check_setup.py
```

Mac 上开发：没有系统 pwsh 时，可用 PowerShell 官方 GitHub 发行版的便携包，`PWSH` 环境变量指向它。

test-reader.ps1 源码含中文且为 UTF-8，PowerShell 7 可直接读取；Windows PowerShell 5.1 执行测试文件时需要带 BOM 编码。实际 start.ps1 是 ASCII 内容，正常运行仍只需系统 PowerShell 5.1。lupa 仅测试依赖，优先装在虚拟环境；不要提交该环境。

## 停止和卸载

停止读者只停止 JSON 刷新，不会关闭游戏内采样。需要停用采样时，在游戏插件管理中禁用 LocalContext 并按游戏正常流程重新加载。聊天记录由游戏自身控制，当前插件不恢复原来的 LoggingChat 状态。不要擅自删除原始日志或影响其他插件的记录需求。

## AI 使用

游戏电脑上的 AI 客户端通过 MCP（见 README）读取；回答前应看 freshness。网页版 ChatGPT 读不到本地文件，不支持（D12）。将上下文提供给在线 AI 会把那部分数据发送给服务，本地采集本身没有网络请求。
