# AI CLI Kickstarter

给完全不懂计算机的人安装第一个 AI CLI，然后由这个 AI 接管后续指导。

## 支持

- Qwen Code
- Kimi Code
- CodeBuddy CLI
- macOS
- Linux
- Windows
- 中文 / English

## 使用

### macOS

解压后双击 `Start-macOS.command`。若 macOS 阻止运行，右键文件并选择“打开”。

### Linux

打开终端，在本目录运行：

```bash
bash Start-Linux.sh
```

### Windows

双击 `Start-Windows.cmd`。它会启动 PowerShell 状态机。

若出现「Windows 已保护你的电脑」（SmartScreen）提示，点击「更多信息」，再点击「仍要运行」。这是 Windows 对从网上下载的文件的常规提醒。

## 安装前须知

- 启动器会先把官方安装脚本下载到临时文件，但不会立刻执行。
- 确认页会显示初始地址、重定向后的最终 HTTPS 地址和 SHA-256；只有明确输入 `y` 才会执行，直接按 Enter 默认取消。
- AI CLI 通常仍需要供应商账号、会员资格或 API Key，具体费用、数据使用规则和地区可用性以供应商当前说明为准。
- 交接 Prompt 是使用建议，不是强制安全边界。启动 AI CLI 后仍应认真阅读每一次文件修改和命令执行确认。

## Prompt 库：安装之后做什么

安装并验证成功时，启动器会显示一段「交接 Prompt」。复制它，在 AI CLI 启动后粘贴，让 AI 检查电脑环境并建议下一步——那是第 0 个任务。下面是后续任务清单：每个 Prompt 对应一个完整任务（Mission），而不是一句泛泛的提问。

用法：每次开新会话，先粘贴「通用前置」，再粘贴一个任务 Prompt。

### 通用前置（每次新会话先粘贴）

```text
请把我当作计算机新手，始终用中文回复。
遇到我可能不懂的概念，先用通俗语言解释再继续。
动手改动之前：说明目标、说明风险、估计所需时间。
修改任何配置文件前先备份。
涉及管理员权限、删除、覆盖、付费或隐私的操作，先征得我的同意。
每完成一步都验证结果。
优先选择能解决问题的最简单方案；有多个好选项时只推荐最优的一个，并说明理由。
```

### 起步

**1. 初始化这台电脑**

```text
请帮我把这台电脑配置成适合现代 AI 开发的环境。
只安装必要的工具，例如：包管理器、终端增强、字体、Shell 提示符、常用命令行工具。
请根据我的操作系统选择最合适的工具。
```

**2. 打造 AI 工作站**

```text
请把这台电脑打造成以 AI 为核心的工作站。
针对编程、写作、研究、终端、浏览器、AI Agent 分别推荐最合适的工具。
逐项征得我同意后再安装。
```

### 体检与治理

**3. 全面体检**

```text
请对这台电脑做一次全面体检。
检查：硬件、操作系统、存储、内存、安全、备份、已安装软件、开发环境。
找出问题，先列出问题清单和修复方案，经我逐项确认后再修复。
```

**4. 终端环境审计**

```text
请检查我的终端环境。
优化：Shell、PATH、别名、提示符、字体、包管理器、开发工具。
清理过时的配置，保持整体简洁、易于维护。
```

**5. 软件治理**

```text
请审计这台电脑上安装的所有软件。
找出：重复的、过时的、不再需要的、相互冲突的软件。
告诉我哪些应该删除、更新或替换并说明理由，经我确认后执行。
```

**6. 存储清理**

```text
请分析这台电脑的存储使用情况。
找出：大文件、重复文件、不再需要的下载、临时文件。
给出清理方案。未经我确认不得删除任何文件；删除时优先使用可恢复的方式（如回收站）。
```

### 网络

**7. 局域网审计**

```text
请帮我检查这里的局域网。
识别网内设备：电脑、NAS、打印机、路由器、交换机、Wi-Fi。
只做只读探测，不要修改任何设备的配置。
找出性能、安全、易用性方面的问题，给出改进建议。
```

**8. 搭建跨地点私有网络**

```text
请帮我把多个地点的设备连成一个私有网络。
推荐最简单、最安全的架构，并比较可选方案。
我选定方案后，一步一步带我完成搭建。
```

### 进阶

**9. 自动化**

```text
请帮我找出可以自动化的重复性工作。
先问我平时经常手动做哪些事，再判断哪些值得自动化、哪些不值得。
只实现我批准的自动化，并解释每个自动化是如何工作的。
```

**10. 长期模式：我的 IT 工程师**

```text
从现在起，请作为我的私人 IT 工程师。
我提出需求时，选最简单可靠的方案；如果存在明显更好的做法，先说明理由再推荐。
帮助我逐步变得更懂电脑，但不要一次教太多。
```

## 状态机

`LANGUAGE → PROBE → SELECT → PRECHECK → DOWNLOAD → CONFIRM → INSTALL → VERIFY → HANDOFF`

下载和安装失败时进入 `ERROR`，用户可以重试、换工具或退出。安装器结束但命令暂时不可见时进入 `RESTART_REQUIRED`，不会错误地进入交接流程。

## 网络检测

启动器请求：

`https://www.google.com/generate_204`

它只判断当前 Terminal/PowerShell 是否能直接连接 Google，不推断用户所在地，也不推断其他国际服务是否可用。

## 安装来源

- Qwen Code：`https://qwen-code-assets.oss-cn-hangzhou.aliyuncs.com/installation/install-qwen-standalone.*`
- Kimi Code：`https://code.kimi.com/kimi-code/install.*`
- CodeBuddy CLI：`https://www.codebuddy.cn/cli/install.*`（官方文档当前标注 native installer 为 Beta）

启动器仅允许上述官方 HTTPS 路径，以及 Kimi 当前使用的 `https://cdn.kimi.com/kimi-code/` 重定向路径。遇到其他重定向会在执行前停止。

信任模型：启动器会显示所下载脚本的 SHA-256，并将脚本放在独立子进程中执行；但该摘要没有与供应商签名或仓库内固定值比较，因此只能用于审计和识别变化，不能证明脚本本身可信。明确确认执行仍表示信任对应供应商。

## 开发

- Bash 离线测试：`bash tests/run-tests.sh`
- Windows PowerShell 离线测试：`powershell -NoProfile -File tests/run-tests.ps1`
- 供应商地址实时检查：`bash tests/check-provider-urls.sh`（只下载，不执行）
- Lint：`shellcheck kickstarter.sh Start-Linux.sh Start-macOS.command tests/*.sh tests/stubs/*`
- CI 在每次 push/PR 时运行 ShellCheck、PSScriptAnalyzer 和两套离线测试；每周及手动触发时检查供应商地址
- `kickstarter.sh` 与 `kickstarter.ps1` 互为镜像，修改状态或文案时需要同步两个文件

## 许可证

MIT，见 [LICENSE](LICENSE)。
