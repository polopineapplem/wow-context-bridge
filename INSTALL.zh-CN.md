# 安装指南

[English](INSTALL.md) | **中文**

让电脑上的 AI 客户端（Claude Desktop、ChatGPT 桌面客户端、Codex）读取你 WoW Forever 角色的实时信息：等级、位置、任务进度、装备。然后你可以直接问“这个角色下一步做什么”。

数据只在你自己的电脑上，不上传、不联网。（你向 AI 提问时，AI 客户端会把相关信息发给它的服务商，这和平时聊天一样。）

AI 助手请看“给 AI 助手的安装步骤”。

## 你需要什么

- 一台 **Windows** 电脑或 **Mac**，装有 **WoW Forever** 客户端（`_forever_` 文件夹里，Windows 有 `Wow.exe`，macOS 有 `World of Warcraft.app`）。已验证版本：1.60.1.71139、Interface 16001、简体中文客户端。插件只在 Interface 16001 下输出数据。
- 至少一个 AI 桌面客户端：Claude Desktop、ChatGPT 桌面客户端或 Codex。网页版读不到本地数据。
- **Windows：** 不需要再装任何东西，系统自带的 Windows PowerShell 就够了。
- **macOS：** 先装一次 PowerShell 7：`brew install --cask powershell`（或用微软的安装包）。不需要 Python。

下面每一步都写了 Windows 文件（`.bat`）和 Mac 文件（`.command`），双击你系统对应的那个。Mac 第一次双击可能被系统拦截，这时右键该文件 → 打开。

## 安装（第一次）

1. **下载本仓库。** 在 GitHub 页面点 Code → Download ZIP 后解压，或者 `git clone`。放在固定位置，例如 `文档\wow-context-bridge`，以后不要移动，因为 AI 客户端的配置会记住这个路径。
2. **双击 `start.bat`**（Windows）**或 `start.command`**（macOS）。它会：
   - 自动找到游戏目录（找到多个或找不到时会提示，用 `-GameRoot` 指定，见下方“常见问题”）；
   - 把 `LocalContext` 插件复制到游戏的 `Interface\AddOns`；
   - 开始读取数据。**这个窗口要一直开着。**
3. **完全退出游戏再重新打开**，登录角色。游戏开着时装的插件，要重启后才会加载。
4. **双击 `install-mcp.bat` / `install-mcp.command`。** 它会把本工具登记到 Claude Desktop 和 Codex / ChatGPT 桌面客户端的配置里，保留你已有的设置，改之前自动备份。
5. **完全退出并重新打开 AI 客户端**（右下角托盘图标里也要退出）。
6. **双击 `check-setup.bat` / `check-setup.command`**，逐项检查。全部是 `[PASS]` 就好了；有 `[FAIL]` 时，每一项下面会写怎么修。
7. 在 AI 客户端里问：**这个角色下一步做什么？** 回答里应该会说明数据是几秒前的。

## 每次玩的时候

先双击 `start.bat` / `start.command`（窗口开着），再开游戏。AI 客户端不需要再配置。没有开 `start.bat` 时，AI 会告诉你“读取器没在运行，数据是旧的”。

## 更新

下载新版本覆盖原文件夹（或 `git pull`），双击 `start.bat`（会更新插件），然后重启游戏。文件夹位置没变就不用重新运行 `install-mcp.bat`。

## 可选：网页版和手机上的 Claude（远程上传）

上面的一切都只在你的电脑上。网页版 Claude（claude.ai）和手机 App 运行在 Anthropic 的云端，读不到你的电脑，所以这个可选步骤把快照发到**你自己的** Cloudflare 免费服务器上，Claude 再从那里用同样的只读工具读取。不设置就不会上传。

**ChatGPT：** Plus 方案的 ChatGPT 网页和 App 用不了。截至 2026 年 11 月，OpenAI 只给 Business、Enterprise、Edu 开放自定义 MCP 服务器（Pro 只读），而且只支持 OAuth 或无登录，本服务器不提供这两种方式。详见 [docs/REMOTE_MCP.md](docs/REMOTE_MCP.md)。在游戏电脑上，ChatGPT 桌面应用仍可使用上面的本地方式。

需要：一个免费的 [Cloudflare](https://dash.cloudflare.com/sign-up) 账户；游戏电脑上装好 [Node.js](https://nodejs.org) LTS。

1. **部署服务器**（只做一次）。在终端里，从本文件夹运行：
   ```
   cd remote
   npx wrangler@4 login
   npm run deploy
   ```
   `login` 会打开浏览器登录 Cloudflare。`deploy` 会打印你的服务器地址，形如 `https://wow-context-bridge.<你的名字>.workers.dev`。
2. **连接读取器。** 回到本文件夹，双击 `configure-remote.bat`（Windows）或 `configure-remote.command`（macOS），粘贴地址。它会生成两把随机密钥（一把上传用，一把读取用），保存在你的用户文件夹里，**不在**本仓库里：
   - Windows：`%APPDATA%\wow-context-bridge\remote.json`
   - macOS：`~/Library/Application Support/wow-context-bridge/remote.json`
3. **把密钥存到服务器并测试：**
   - Windows：`configure-remote.bat -SetSecrets -Check`
   - macOS：`./configure-remote.command -SetSecrets -Check`

   两行都应显示 `PASS`。第一次部署后马上测试，出现 `FAIL ... SSL connection could not be established` 是正常的：新的 `workers.dev` 地址要几分钟（实测约 2 分钟）HTTPS 才能用。等一下，再只加 `-Check` 运行一次。
4. **重启 `start.bat` / `start.command`**，应显示 `Remote upload ON`。等级、区域、任务或装备变化，或者移动超过地图的 3% 时，它会发送快照。最快 30 秒一次，另外每 3 分钟发一次心跳。
5. **在 Claude 里添加连接器**（claude.ai → Customize → Connectors → **+ Add** → **Add custom connector**）。按 `configure-remote` 打印的设置填写，加 `-ShowConnector` 再运行一次可以重新显示：
   - Authentication 选 **No sign-in**。
   - 如果对话框里有 **Request headers**：URL 填 `https://…workers.dev/mcp`，添加 `authorization` 请求头，值为 `Bearer <读取密钥>`。
   - 没有的话：URL 填 `https://…workers.dev/mcp/<读取密钥>`。
6. 问 Claude：“这个角色下一步做什么？”超过 4 分钟的数据会标为过期。

**上传的内容：** 和 `player.json` 相同的数据，加上最近 50 条变化记录。从不上传聊天记录。拿到读取密钥或含密钥 URL 的人都能读取你的角色，所以两者都不要外传。泄露了就运行 `configure-remote -NewTokens -SetSecrets`，再重新添加连接器。

**关闭：** 运行 `configure-remote.bat -Disable`（或 `./configure-remote.command -Disable`），然后重启读取器。要删除服务器和上面的数据，在 `remote` 文件夹里运行 `npx wrangler@4 delete`。

**费用：** 免费方案每天 10 万次请求。本工具每天最多约 2,900 次上传，不会产生费用。

## 卸载

1. 运行 `install-mcp.ps1 -Uninstall`（Windows：`powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install-mcp.ps1 -Uninstall`；macOS：`pwsh -NoProfile -File ./install-mcp.ps1 -Uninstall`），从 AI 客户端配置里移除本工具。
2. 删除游戏目录下的 `Interface\AddOns\LocalContext` 文件夹（或在游戏插件列表里禁用它）。
3. 删除本文件夹。

## 隐私须知

- 插件只使用游戏的公开插件 API。不读内存、不模拟键盘鼠标、不发聊天、不联网。
- 为了把数据传出游戏，插件会**开启游戏的聊天记录**（`Logs\WoWChatLog.txt`）。这份记录也会包含**私聊**等其他聊天内容。本工具只读取自己的数据行，不会删除这个文件。
- 产生的 `player.json` 和 `history.jsonl` 包含角色名和位置，不要上传或分享。
- **Mac 上文件夹放在“文稿”(Documents)、桌面、下载或 iCloud 云盘里时：** macOS 不让 AI 应用读取这些文件夹。此时 `player.json`、`history.jsonl` 和一份 MCP 服务器副本改放在 `~/Library/Application Support/wow-context-bridge`。`start.command` 和 `install-mcp.command` 会自动处理。

## 常见问题

先运行 `check-setup.bat`，它会指出具体是哪一步出了问题。

| 情况 | 解决 |
| --- | --- |
| 提示找不到游戏，或找到多个 | Windows：`powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\start.ps1 -GameRoot 'E:\你的路径\World of Warcraft\_forever_'`。macOS：`pwsh -NoProfile -File ./start.ps1 -GameRoot '/Applications/World of Warcraft/_forever_'` |
| Mac 提示找不到 pwsh | 运行 `brew install --cask powershell`，然后再双击 |
| AI 说没有角色数据 | 确认已重启游戏并登录了角色，`start.bat` 窗口开着，等约 20 秒 |
| AI 说数据是几分钟前的 | 战斗中、读条或下线时不会更新，属于正常；否则看 `check-setup.bat` 的“game log”一项 |
| AI 客户端里没有 wow-context | 重新运行 `install-mcp.bat`，然后**完全**退出并重开客户端 |
| Mac：Claude 日志 `~/Library/Logs/Claude/mcp-server-wow-context.log` 里有 “Access to the path … is denied” | 文件夹在文稿/桌面/下载/iCloud 里。更新到最新版，运行 `install-mcp.command`，重新打开 `start.command`，然后完全退出（Cmd+Q）并重开 Claude |
| 移动了文件夹 | 重新运行 `install-mcp.bat` |

## 给 AI 助手的安装步骤

本节写给帮用户安装的 AI agent（Codex、Claude Code 等）。命令都在本仓库根目录运行。

1. 找到游戏目录：运行 `check-setup.ps1 -Json`（下面所有 `.ps1`，Windows 用 `powershell.exe -NoProfile -ExecutionPolicy Bypass -File <脚本>` 运行，macOS 用 `pwsh -NoProfile -File <脚本>` 运行；Mac 上要先装 PowerShell 7，并告诉用户）。看 `game folder` 一项。找到多个时，**问用户选哪个**，不要猜。
2. 运行 `start.ps1`（必要时加 `-GameRoot`）。它会安装插件，然后一直运行。请在后台或单独窗口运行，并记录实际命令行。不要因为旧 PID 文件就结束进程。
3. 游戏已在运行时，**请用户自己**重启游戏并登录。不要替用户操作游戏，也不要发送任何游戏输入。
4. 运行 `install-mcp.ps1`。想先预览就加 `-DryRun`。它只修改 `wow-context` 一个条目，并会自动备份。
5. 请用户完全退出并重开 AI 客户端。
6. 再运行 `check-setup.ps1 -Json`，直到 `ok=true`。按每项的 `fix` 处理，需要用户动手的步骤要告诉用户。
7. 回答游戏问题时遵循 `docs/ADVISOR.md`。
8. 远程上传（“可选：网页版和手机上的 Claude”）只在用户要求时设置。登录 Cloudflare、部署、添加 Claude 连接器是用户自己的步骤：给出准确的命令。不要把用户的密钥或服务器地址打印或提交到公开的地方。
9. 不要提交或分享 `player.json`、`history.jsonl` 和游戏聊天记录（用户自己开启的远程上传是唯一例外，它从不发送聊天记录）；不要删除聊天记录。开发规则见 `AGENTS.md`。
