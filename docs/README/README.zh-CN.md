<div align="center">

<img src="../images/appicon.png" alt="LockIME" width="128">

# LockIME Voice

[English](../../README.md) · **简体中文** · [繁體中文](README.zh-TW.md) · [日本語](README.ja.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Español](README.es.md) · [Português](README.pt.md) · [Русский](README.ru.md)

[![CI](https://img.shields.io/github/actions/workflow/status/zhangsiqiang519/LockIME-Voice/ci.yml?branch=main&label=CI)](https://github.com/zhangsiqiang519/LockIME-Voice/actions/workflows/ci.yml)
[![许可证: GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-3A5BD9)](../../LICENSE)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-000000?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-F05138?logo=swift&logoColor=white)](https://swift.org)

</div>

> **LockIME Voice 源码分支。** 这个 GPL-3.0 二开版本增加了可配置的语音输入工作流。`v0.1.2` 提供 ad-hoc 签名的预览安装包，但不提供 Developer ID 签名、公证、Sparkle 更新或 Homebrew 安装。

一款 macOS 菜单栏应用，用于**锁定你的键盘输入源**。每当你（或其他应用）切换输入法时，LockIME 会立即切回被锁定的那个——可以是全局的、按前台应用区分的，或者（在可选的增强模式下）按浏览器 URL 区分的。

> macOS 14+ · 支持 Apple silicon 与 Intel——两个独立的应用，请下载与你的 Mac
> 匹配的 `-arm64` 或 `-x86_64` 文件 · 基于 SwiftUI 构建，macOS 26 (Tahoe) 上
> 呈现 Liquid Glass。

## Screenshots

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="../images/settings-general-zh-CN-dark.png">
    <img alt="常规设置" src="../images/settings-general-zh-CN-light.png" width="32%">
  </picture>
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="../images/settings-app-rules-zh-CN-dark.png">
    <img alt="按应用规则" src="../images/settings-app-rules-zh-CN-light.png" width="32%">
  </picture>
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="../images/settings-url-rules-zh-CN-dark.png">
    <img alt="按 URL 规则" src="../images/settings-url-rules-zh-CN-light.png" width="32%">
  </picture>
</p>

## Changes in LockIME Voice

相比上游 LockIME，本分支包含以下具体改动：

- **语音输入法可配置**——不写死任何输入法，可选择豆包、微信或其他已安装输入法。
- **两个独立快捷键**——LockIME 有自己的全局语音快捷键，并代你发送输入法内部配置的那个快捷键。两者必须不同，否则同一个组合键会被处理两次，macOS 就会提示快捷键冲突；支持左右修饰键和多键组合。
- **三种语音行为**——再次按下结束、按住说话、任意键结束，与输入法自身设置保持一致。
- **临时接管输入法**——语音期间暂停普通锁定规则，避免刚切到语音输入法就被切回默认输入法。
- **恢复全局默认输入法**——恢复目标直接取自 **App Rules** 的全局默认规则，不再重复设置“日常输入法”。
- **连续使用更可靠**——增加输入法确认、过期任务取消、安全超时、合成事件过滤和会话快捷键快照。
- **菜单更清晰**——全局默认输入法排在最前，并用图钉代替对勾标记。

![LockIME Voice 语音输入设置](../images/settings-voice-input-zh-CN.png)

## Install

下载与你的 Mac 匹配的安装包：

- [Apple silicon (arm64)](https://github.com/zhangsiqiang519/LockIME-Voice/releases/download/v0.1.2/LockIME-Voice-0.1.2-arm64.dmg)
- [Intel (x86_64)](https://github.com/zhangsiqiang519/LockIME-Voice/releases/download/v0.1.2/LockIME-Voice-0.1.2-x86_64.dmg)

SHA-256 校验和：

- `LockIME-Voice-0.1.2-arm64.dmg`: `acd3602c05428d38e0713e186757b25bce1d57df0410039ae147431d5c18e780`
- `LockIME-Voice-0.1.2-x86_64.dmg`: `914338ea7295d5a0713168035f1618cdb2004cd782ab24a5a1ef2b4c8a6d0d9f`

打开 DMG，把 **LockIME Voice** 拖入“应用程序”。本预览版仅使用 ad-hoc 签名、**未公证**，因此首次启动会被 Gatekeeper 拦下：

1. 双击 **LockIME Voice**。macOS 会以「Apple 无法验证 LockIME Voice 是否包含恶意软件」为由拒绝——这是预期现象，不代表下载损坏。
2. 打开 **系统设置 ▸ 隐私与安全性**，滚动到**安全性**区域。**LockIME Voice** 会出现在那里，后面有**仍要打开**按钮。
3. 点击**仍要打开**，验证身份，再在随后弹出的对话框里点**打开**。此后每次启动都会正常进行。

请只信任从本仓库 Release 页面下载、且 SHA-256 与上方校验和一致的副本——这才是对未公证构建点「仍要打开」的前提。启动后按提示授予**辅助功能**权限（语音输入工作流需要它，发送键盘事件的授权也在同一处）。

也可以从源码构建：

```sh
brew install xcodegen xcbeautify
make build
open "build/DerivedData/Build/Products/Debug/LockIME Voice Dev.app"
```

重新安装或构建 ad-hoc 签名应用后，可能需要再次授予 macOS 权限。目前不支持自动更新。

## Features

- **即时重新锁定**——每当你（或其他应用）切换输入源时，立即切回被锁定的那个，可全局或按应用生效。
- **冲突感知**——当另一个程序不断把输入源改回它自己想要的（比如自带输入法管理的游戏）时，LockIME 会识别出这种拉锯，短暂停手而不是无休止地来回切换，并在激活日志中记下*检测到冲突*；给这类应用单独设置一条*忽略*或*切换为*规则即可一劳永逸。
- **裸进程规则**——不以 `.app` 包、而以裸可执行文件运行的程序（比如由第三方启动器拉起的 Minecraft 的 `java`）同样可以拥有规则：在其运行期间，应用选择器会以合成的 `process:<executable>` 身份（例如 `process:java`）把它们列出来。
- **锁定或切换**——按应用和按 URL 的规则既可以*锁定*某个输入源（一旦偏离就重新切回），也可以在你切到该应用或页面时只*切换*一次，之后任你自由更改。
- **全局锁定，或仅切换**——给全局默认输入源设定三种行为之一：*锁定*，在所有地方把它钉住；*切换*，每当某个应用回落到全局默认（它没有自身规则，或其规则为*使用默认*）时为你切换一次，随后便放手让你自由；或**无**，即完全没有任何全局行为——此时 LockIME 只通过你的按应用和按 URL 规则发挥作用。*切换*会在每次采用全局默认时主动为你切入；**无**在全局层面什么都不做。
- **灵活的 URL 匹配**——按 URL 规则（增强模式）可以按某个域名及其子域名、某个精确域名、某个域名关键词，或针对完整 URL 的正则表达式来匹配，并按你拖动排列出的优先级顺序生效——第一个命中者胜出。
- **菜单栏控制**——在菜单栏激活/停用、切换被锁定的输入源、查看当前输入源、追踪激活次数。
- **键盘快捷键**——可配置的全局快捷键用于开关 LockIME、切换被锁定的输入源（上一个 / 下一个），以及针对当前最前台应用的快捷键，用于切换或移除该应用的规则。
- **语音输入工作流**——按下 LockIME 自己的语音快捷键，它会代你发送输入法内部配置的语音快捷键。打开「自动切换输入法」后，它还会在语音期间切到设定的语音输入法，结束后恢复你的日常输入法。两个快捷键务必保持不同。
- **登录时启动**——登录后自动启动（默认关闭）。
- **浅色 / 深色模式**——统一的、系统原生的设计语言，自动适配浅色与深色外观，并配有定制应用图标。参见 [docs/DESIGN.md](../DESIGN.md)。
- **实时语言切换**——在 9 种语言间即时切换，无需重启：English、简体中文、繁體中文、日本語、Français、Deutsch、Español、Português、Русский。
- **24 小时激活日志**——回顾切换了什么、为什么、持续了多久。
- **配置备份**——把按应用和按 URL 的规则导出为 `.lockime` 文件，再导入回来；导入前会有一个预览步骤，先列出新增、冲突与移除项，确认后再应用。
- **超小体积**——整个应用打包成不到 3 MB 的 `.dmg`。
- **核心锁定无需系统权限**——可选的、受 Accessibility 把关的增强模式可解锁更细粒度的按 URL / 聚焦字段规则。
- **自动化**——通过 `lockime-voice://` URL scheme，其他应用、脚本和 Shortcuts 都能驱动 LockIME（详见下文）。

## Voice Input Workflow

语音输入法完全可配置；LockIME Voice 不会写死豆包、微信或其他输入法。

1. 打开 **Settings ▸ Voice Input**，启用工作流。
2. 录入 **输入法语音快捷键**——即该输入法自身语音功能所用的快捷键。请先在输入法内部设好它，并让它与 LockIME 自己的快捷键不同。
3. 录入 **LockIME 语音快捷键**（在 **Settings ▸ Shortcuts ▸ Global shortcuts** 或同一面板中）。这才是你实际按下的那个键。
4. 可选：如果语音输入法不是你日常使用的输入法，打开 **自动切换输入法** 并选中该输入法。请先在 **Settings ▸ App Rules** 设好全局默认输入法——语音结束后 LockIME 会恢复它。
5. 按提示授予发送键盘事件的权限。

按下 LockIME 的快捷键后，它会发送输入法的语音快捷键，因此语音输入会在当前输入法中启动。打开自动切换时，LockIME 会先切到设定的语音输入法，等待 macOS 确认切换，并在语音结束或安全超时后恢复全局默认输入法。

由于 LockIME 只**发送**该快捷键、从不监听你的按键，两个快捷键必须是不同的组合。把它们设成同一个组合会让冲突重新出现：同一个按键被处理两次，macOS 或输入法就会提示快捷键冲突。

请在 TextEdit 等普通文本框中验证。只看到语音面板不算成功，识别文字必须实际插入当前光标位置。
## Comparison

LockIME 最被广泛使用的两个替代品是
**[Input Source Pro](https://github.com/runjuu/InputSourcePro)** 和
**[KeyboardHolder](https://github.com/leaves615/KeyboardHolder)**，此外还有一长串规模更小的开源和
CLI 工具。它们都会在你于应用或站点之间移动时*切换*输入源；而 LockIME
围绕持续**锁定**构建——一旦输入源偏离就立即重新应用，同时任何规则仍可回退为一次性*切换*。

| | LockIME | Input Source Pro | KeyboardHolder |
|---|---|---|---|
| 价格 | 免费 | 免费 | 免费（捐赠） |
| 开源 | GPL-3.0 | GPL-3.0 | ✗（闭源） |
| 最低 macOS | 14 | 11 | 10.15 |
| 下载体积 | < 3 MB | ≈ 7.6 MB | ≈ 4.5 MB |
| 按应用规则 | ✓ | ✓ | ✓ |
| 按网站 / URL 规则 | ✓ | ✓ | ✓ |
| URL 匹配类型 | 子域名 · 精确 · 关键词 · 正则 | 子域名 · 精确 · 正则 | 域名（通配符） |
| 地址栏（URL 字段）规则 | ✓（锁定/切换/优先级） | ✓（默认输入源） | — |
| 持续重新锁定 | ✓ | ✗ | ✗ |
| 每条规则可锁定*或*一次性切换 | ✓ | ✗ | ✗ |
| 全局键盘快捷键 | ✓ | ✓ | ✗ |
| 菜单栏控制 | ✓ | ✓ | ✓ |
| 屏幕输入提示 | ✗ | ✓ | ✓（可选） |
| 24 小时激活日志 | ✓ | ✗ | ✗ |
| 配置备份 / 导入 | ✓（`.lockime`，带审阅） | ✓（导出/导入 + CLI） | — |
| URL scheme 自动化 | ✓（`lockime-voice://`，x-callback-url） | 部分（`inputsourcepro://` 导入） | ✗ |
| 界面语言 | 9（实时切换） | 6 | zh · en · ja |
| 系统权限 | 核心无需 · 按 URL 需 Accessibility | 核心无需 · 按 URL 需 Accessibility | Accessibility¹ |
| 自动更新 | ✗（仅源码分支） | ✓ | ✓ |
| 持续维护中（2026） | ✓ | ✓ | ✓ |

¹ KeyboardHolder 没有说明其权限要求；其按网站规则要读取浏览器地址栏，实际上需要
Accessibility 访问权限。“—” 表示未记录的能力，而非确认缺失。

**如何选择：** Input Source Pro 拥有最大的社区和最丰富的屏幕输入提示；KeyboardHolder
则是一个精致、零配置的按应用记忆。当你想把一个输入源*钉住*——按应用、按 URL
或在地址栏，每当有东西改动它就立即重新应用——而不仅仅是在你到达时才切换它，就该用 LockIME。

**其他工具：** [SwitchKey](https://github.com/itsuhane/SwitchKey)（仅按应用，已不再维护）、
[Kawa](https://github.com/hatashiro/kawa)（手动、快捷键驱动）、InputSwitcher（免费增值，仅按应用），以及
[macism](https://github.com/laishulu/macism)（一个命令行构建块，而非图形界面切换器）。

> 对比基于 Input Source Pro 2.11.0 与 KeyboardHolder 1.14.10，采集于 2026 年中——细节会变化，欢迎指正。

## Automation

LockIME 提供了 `lockime-voice://` URL scheme，让其他应用、脚本、Shortcuts 和启动器都能驱动它——开启或关闭它、重新指定输入源、管理规则，并通过 [x-callback-url](https://x-callback-url.com) 回调读回状态。它默认关闭——请在**设置 ▸ 通用 ▸ 自动化**中开启它。

```sh
open "lockime-voice://lock"
open "lockime-voice://lock-to-source?id=com.apple.keylayout.ABC"
open "lockime-voice://set-app-rule?bundle=com.apple.Terminal&mode=lock&source=com.apple.keylayout.ABC"
```

完整参考：**[URL Scheme API](../URL-Scheme-API/README.zh-CN.md)**。

## Design

LockIME 遵循单一的设计系统（`Sources/LockIME/UI/DesignSystem.swift`）：语义化颜色、系统材质和 SF Symbols 驱动浅色/深色适配；Liquid Glass 仅保留给浮层/导航层使用。品牌强调色 "Lock Indigo" 以 `AccentColor` 资源的形式提供。完整规范见 [docs/DESIGN.md](../DESIGN.md)。

应用图标以编程方式生成（不使用任何设计工具）——用以下命令重新生成：

```sh
./scripts/make-appicon.sh   # renders the master via SwiftUI and rebuilds the appiconset
```

## Development

需要 Xcode 26+（应用本身以 macOS 14+ 为目标），以及 [XcodeGen](https://github.com/yonaskolb/XcodeGen) + [xcbeautify](https://github.com/cpisciotta/xcbeautify)（`brew install xcodegen xcbeautify`）。

```sh
make gen     # generate LockIMEVoice.xcodeproj from project.yml
make build   # build (Debug)
make run     # build & launch
make test    # run unit tests
make archive # ad-hoc-signed Release archive
```

Xcode 项目由 `project.yml` 生成，不纳入版本控制。

涉及硬件的集成测试（真实的 TIS 切换）已从 `make test` 中排除；用 `make test-hw` 运行它们（会短暂改变输入源）。

## Releasing

预览 DMG 目前由维护者手动构建和上传。Developer ID、公证、Sparkle、每夜构建和 Homebrew 流程仍保持停用。参见 [docs/RELEASING.md](../RELEASING.md) 了解打包与校验方式。

## Architecture

- **LockIMEKit**（静态库）——纯粹的、经过完整单元测试的逻辑，仅使用系统框架：锁定引擎、应用监视器、规则、增强（Accessibility）观察器、日志模型、本地化。
- **LockIME Voice**（应用）——`@main`、SwiftUI UI、设计系统，以及面向 Sparkle、KeyboardShortcuts 和 PermissionFlow 的轻量集成适配层。

## License

Copyright © 2026 Hangzhou Wumou Software Co., Ltd.

Modifications © 2026 zhangsiqiang519.
