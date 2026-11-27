# 安装指南

[English](INSTALL.md) | **中文**

让电脑上的 AI 客户端（Claude Desktop、ChatGPT 桌面客户端、Codex）读取你 WoW Forever 角色的实时信息：等级、位置、任务进度、装备。然后你可以直接问“这个角色下一步做什么”。

数据只在你自己的电脑上，不上传、不联网。（你向 AI 提问时，AI 客户端会把相关信息发给它的服务商，这和平时聊天一样。）

AI 助手请看“给 AI 助手的安装步骤”。

## 你需要什么

- 一台 **Windows** 电脑，装有 **WoW Forever** 客户端（`_forever_` 文件夹里有 `Wow.exe`）。已验证版本：1.60.1.71139、Interface 16001、简体中文客户端。插件只在 Interface 16001 下输出数据。
- 至少一个 AI 桌面客户端：Claude Desktop、ChatGPT 桌面客户端或 Codex。网页版读不到本地数据。
- 不需要安装 Python 或其他软件，系统自带的 Windows PowerShell 就够了。

## 安装（第一次）

1. **下载本仓库。** 在 GitHub 页面点 Code → Download ZIP 后解压，或者 `git clone`。放在固定位置，例如 `文档\wow-context-bridge`，以后不要移动，因为 AI 客户端的配置会记住这个路径。
2. **双击 `start.bat`。** 它会：
   - 自动找到游戏目录（找到多个或找不到时会提示，用 `-GameRoot` 指定，见下方“常见问题”）；
   - 把 `LocalContext` 插件复制到游戏的 `Interface\AddOns`；
   - 开始读取数据。**这个窗口要一直开着。**
3. **完全退出游戏再重新打开**，登录角色。游戏开着时装的插件，要重启后才会加载。
4. **双击 `install-mcp.bat`。** 它会把本工具登记到 Claude Desktop 和 Codex / ChatGPT 桌面客户端的配置里，保留你已有的设置，改之前自动备份。
5. **完全退出并重新打开 AI 客户端**（右下角托盘图标里也要退出）。
6. **双击 `check-setup.bat`**，逐项检查。全部是 `[PASS]` 就好了；有 `[FAIL]` 时，每一项下面会写怎么修。
7. 在 AI 客户端里问：**这个角色下一步做什么？** 回答里应该会说明数据是几秒前的。

## 每次玩的时候

先双击 `start.bat`（窗口开着），再开游戏。AI 客户端不需要再配置。没有开 `start.bat` 时，AI 会告诉你“读取器没在运行，数据是旧的”。

## 更新

下载新版本覆盖原文件夹（或 `git pull`），双击 `start.bat`（会更新插件），然后重启游戏。文件夹位置没变就不用重新运行 `install-mcp.bat`。

## 卸载

1. 在 PowerShell 里运行：`powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install-mcp.ps1 -Uninstall`，从 AI 客户端配置里移除本工具。
2. 删除游戏目录下的 `Interface\AddOns\LocalContext` 文件夹（或在游戏插件列表里禁用它）。
3. 删除本文件夹。

## 隐私须知

- 插件只使用游戏的公开插件 API。不读内存、不模拟键盘鼠标、不发聊天、不联网。
- 为了把数据传出游戏，插件会**开启游戏的聊天记录**（`Logs\WoWChatLog.txt`）。这份记录也会包含**私聊**等其他聊天内容。本工具只读取自己的数据行，不会删除这个文件。
- 产生的 `player.json` 和 `history.jsonl` 包含角色名和位置，不要上传或分享。

## 常见问题

先运行 `check-setup.bat`，它会指出具体是哪一步出了问题。

| 情况 | 解决 |
| --- | --- |
| 提示找不到游戏，或找到多个 | 在本文件夹打开 PowerShell，运行：`powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\start.ps1 -GameRoot 'E:\你的路径\World of Warcraft\_forever_'` |
| AI 说没有角色数据 | 确认已重启游戏并登录了角色，`start.bat` 窗口开着，等约 20 秒 |
| AI 说数据是几分钟前的 | 战斗中、读条或下线时不会更新，属于正常；否则看 `check-setup.bat` 的“game log”一项 |
| AI 客户端里没有 wow-context | 重新运行 `install-mcp.bat`，然后**完全**退出并重开客户端 |
| 移动了文件夹 | 重新运行 `install-mcp.bat` |

## 给 AI 助手的安装步骤

本节写给帮用户安装的 AI agent（Codex、Claude Code 等）。命令都在本仓库根目录运行。

1. 确认这是 Windows，并找到游戏目录：运行 `check-setup.ps1 -Json`（下面所有 `.ps1` 都用 `powershell.exe -NoProfile -ExecutionPolicy Bypass -File <脚本>` 运行）。看 `game folder` 一项。找到多个时，**问用户选哪个**，不要猜。
2. 运行 `start.ps1`（必要时加 `-GameRoot`）。它会安装插件，然后一直运行。请在后台或单独窗口运行，并记录实际命令行。不要因为旧 PID 文件就结束进程。
3. 游戏已在运行时，**请用户自己**重启游戏并登录。不要替用户操作游戏，也不要发送任何游戏输入。
4. 运行 `install-mcp.ps1`。想先预览就加 `-DryRun`。它只修改 `wow-context` 一个条目，并会自动备份。
5. 请用户完全退出并重开 AI 客户端。
6. 再运行 `check-setup.ps1 -Json`，直到 `ok=true`。按每项的 `fix` 处理，需要用户动手的步骤要告诉用户。
7. 回答游戏问题时遵循 `docs/ADVISOR.md`。
8. 不要提交或上传 `player.json`、`history.jsonl` 和游戏聊天记录；不要删除聊天记录。开发规则见 `AGENTS.md`。
