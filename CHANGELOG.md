# Changelog

MySwiftAppTools 的版本变动记录。

- 版本号遵循[语义化版本](https://semver.org/lang/zh-CN/)：`MAJOR.MINOR.PATCH`
- 日期格式 `YYYY-MM-DD`
- 条目分类：**新增** / **变更** / **修复** / **移除** / **文档**
- 已知破坏性变更一律用 **BREAKING** 标注，并说明迁移方式
- 完整提交历史见 [GitHub Releases](https://github.com/kyinwind/MySwiftAppTools/releases)

## 依赖版本范围说明（重要）

本包当前处于 `0.x`，SwiftPM 对 `0.x` 的 `from:` 语义是「锁到次版本」：

| App 里写的依赖 | 实际允许的版本范围 |
|---|---|
| `from: "0.1.65"` | `>= 0.1.65, < 0.2.0` |
| `from: "0.2.0"` | `>= 0.2.0, < 0.3.0` |

**推论**：一旦打出 `0.2.0`，所有用 `from: 0.1.x` 的 App **不会**自动升级过去，必须手动改依赖。因此 `0.2.0` 是留给破坏性变更的版本号，`0.1.x` 内只做源兼容改动。

---

## [Unreleased]

暂无待发布改动。

## [0.1.72] — 2026-09-22

### 变更

- **消息历史改为默认关闭。** 现在**必须**显式调用
  `ToastManager.shared.configureToastHistory(isHistoryEnabled: true)` 才会记录任何历史；
  不调用、或调用了但不传这个开关，都不会写入。

  原因：toast 文本常含用户文件路径（「已处理 `/Users/xxx/…`」），写 UserDefaults 是
  有副作用的持久化行为，不该由「调用方没写任何相关代码」被动触发。

  **影响与迁移**：对外 API 签名一个没动，老代码不改也能编译，属于**行为变更**而非
  破坏性 API 变更，因此走 `0.1.x`。但如果你依赖「不配置就自动记录」的旧行为，
  升级后历史会是空的 —— 加一行显式开启即可。已知接入方 RightClickMate
（`RightClickMateApp.swift:92`）与 VideoHero（`VideoHeroApp.swift:159`）
  都已在 App 初始化里显式传了 `isHistoryEnabled: true`，**行为完全不变**。

  内部默认值同步翻转：`ToastHistoryStore.isHistoryEnabled` 与
  `ToastHistoryStore.configure(isHistoryEnabled:)` 的默认值均由 `true` 改为 `false`。
  注意 `ToastHistoryStore.configure(...)` 是**全量重置**语义 —— 包内想记录历史时
  必须显式写 `isHistoryEnabled: true`，否则不传就会被关掉。

### 新增

- **消息历史界面的空态区分**：「功能未开启」（`bell.slash` 图标 + 「消息历史未开启」）
  与「开启了但还没有消息」（`tray` 图标 + 「暂无消息」）现在是两种不同的显示 ——
  不区分的话，App 没开启历史时使用者只看到「暂无消息」，会误以为是自己没产生过消息，
  而不是功能被关着。
  新增文案 key：`Toast.History.disabled` / `Toast.History.disabledHint`（中英同步），
  以及 Preview `"消息历史 · 历史未开启"`。

### 文档

- README 的「快速开始」与「消息历史」章节改为显式开启写法，补充默认关闭的原因与空态说明。
- 新增 `docs/20260922-Toast历史默认关闭-变更方案.md`（含影响面调研、测试清单与拍板记录）。

## [0.1.71] — 2026-09-21

### 修复

- **消息历史界面不跟随 App 内语言切换。** `ToastHistoryView` 原先只认
  `PackageLanguageManager` 的全局值，而全局值是「谁最后设谁赢」的弱一致状态：
  调用方漏一次同步（例如 `onChange` 回调因子树被 `.id(...)` 重建而没触发），
  界面就被过期的全局值钉死在启动语言上。现在视图**优先读 SwiftUI 环境 `Locale`**
  —— `SwiftHelpCenter` 的 `.SHCAppLanguage(...)` 会注入它并在切语言时用 `.id(...)`
  重建子树，环境值由 SwiftUI 负责传播，是强一致的。因此调用方**不需要再写任何桥接
  代码**，只要用了 SHC 的语言 modifier，包内界面就自动跟随。

### 新增

- `EnvironmentValues.packageLanguageResourceName`：子树级语言注入键，
  由 `.packageLanguageRefresh(resourceName:)` 写入，包内视图读它取当前语言。
- `packageL(_:resourceName:arguments:)`：指定 `.lproj` 资源名的查表重载
  （带 label + 数组参数，与可变参数版本不产生重载歧义）。
- `PackageLocalization.resourceName(for:)`：由 `Locale` 推导 `.lproj` 资源名，
  候选名从最具体试到最宽松（`zh-Hans_CN` → `zh-Hans-CN` → `zh-Hans` → `zh`），
  并在 `Bundle.module.localizations` 里做大小写不敏感匹配。

### 变更

- `ToastHistoryView` 的语言优先级调整为：**环境键 > 环境 `Locale` > 全局值 > 系统**。
  环境 `Locale` 刻意排在全局值之前，避免界面被过期的全局值钉死。
- `ToastHistoryWindowController` 改用新的内部根视图 `ToastHistoryWindowRoot`：
  独立窗口拿不到 App 的环境 `Locale`，改由它把全局值注入环境键并观察语言变化。

## [0.1.70] — 2026-09-21

### 新增

- **包内 UI 文案支持运行时切换语言**：`PackageLanguageManager.shared.setLanguage(.english / .zhHans / .custom(_))`；也可 `setResourceName("en")` 直接对接外部语言系统（如 `SwiftHelpCenter`），传 `nil` 回到跟随系统
- **`PackageLanguage`**：`.system`（默认）/ `.zhHans` / `.english` / `.custom(String)`
- **`View.packageLanguageRefresh(resourceName:)`**：套在根视图上，外部语言值一变就自动同步 + 重建整棵子树
- **`View.packageLanguageRefresh()`**：命令式版本，跟随 `PackageLanguageManager.shared.refreshToken`
- `PackageLocalization`：定向 `.lproj` 查表（对外只暴露 `resourceName`）

### 修复

- **App 内切换语言后，包内文案不跟着变。**
  两处都缺：① `packageL` 走 `Bundle.module.localizedString`，而语言由 Foundation 在**进程启动时**
  解析并缓存，App 内改语言不会让它重新解析；② `packageL` 是普通全局函数，不参与 SwiftUI
  依赖追踪，没有任何东西能触发重绘。
  现在 `packageL` 在指定语言时会**显式定位对应 `.lproj` 再查表**（三级回退：lproj Bundle →
  直接读 `.strings` → 标准查表），`ToastHistoryView` 内部也自带观察，语言一变即重建。
  资源名匹配**大小写不敏感** —— 外部语言系统普遍给小写 `zh-hans`，而本包目录是 `zh-Hans.lproj`。

### 兼容性说明

- **源兼容**：全部是新增 API。`packageL(_:_:)` 签名未变；不调用新 API 时 `resourceName` 为 `nil`，
  走原路径，**逐 key 与 0.1.69 一致**（有单测穷举全部 key 守住这条底线）
- **行为变化**：无

## [0.1.69] — 2026-09-21

### 修复

- **`ToastHistoryView` 自身没有背景，裸嵌进别人的容器会整片漏底。**
  界面的 `body` 原先一层背景都没画，显示正常全靠宿主恰好在底下垫了一层（`NSWindow` /
  `.sheet` 自带底色），属于「偶然正确」；一旦裸嵌进 `ZStack` 或自定义容器，透出的就是宿主底色，
  宿主是透明窗口时直接露出桌面。现在默认铺一层系统语义背景
  （macOS `NSColor.windowBackgroundColor` / iOS `UIColor.systemBackground`），
  随浅色深色自动切换，且与窗口、sheet 面板底色一致、无接缝。
- `ToastHistoryWindowController` 显式设置 `isOpaque = true` 与 `backgroundColor`，
  不再依赖 `NSWindow` 的默认值 —— 原先只是碰巧有底，将来改 `styleMask` 或加上
  `titlebarAppearsTransparent` 就可能弄丢。

### 新增

- **`ToastHistoryBackground`**：背景样式三态 —— `.system`（默认）/ `.none`（调用方接管）/ `.color(_)`（注入主题色）
- `ToastHistoryView(background:)` 与 `ToastHistoryWindowController.show(background:)` 新增参数；**带默认值，老调用方源码零改动**

### 变更

- **行为变化**：`ToastHistoryView` 默认多出一层系统背景。若原先在**实例外层**写过 `.background(...)`
  （例如 `ToastHistoryView().background(theme.pageBackground)`），它会被这层新背景盖住 ——
  请改用 `ToastHistoryView(background: .color(theme.pageBackground))`。

## [0.1.68] — 2026-09-21

### 修复

- **刚弹出 Toast 后立即打开消息历史，最新消息文字可能上下镜像。** Toast 状态更新原先使用
  `withAnimation`，它会把同一 runloop 内创建或刷新的历史窗口卷入全局动画事务；macOS 的
  可选择文本层可能因此使用翻转的 AppKit 快照。现在状态层只更新数据，展示动画统一由
  `ToastView.animation(_:value:)` 局部负责，历史窗口不再受到 Toast 动画事务影响。
- 保留消息历史视图的无动画事务作为第二层保护，并补充四个数字格式化文案和“几分钟前”文案的
  回归断言，防止再次出现数字归零或占位符未替换。

## [0.1.67] — 2026-09-21

### 修复

- **消息历史界面里的数字全部显示为 0。** `packageL` 本身是「查表 + 格式化」二合一函数，
  调用处又在外面套了一层 `String(format:)`，内层这次无参调用先把格式化符 `%d` 填成了 0，
  外层拿到的就已经是「0」。症状：「共 0 条」「0 分钟前」「0 条更早的消息」。
  修复：改为直接传参调用 `packageL(key, arg)`，共 4 处（清空确认语、条数、更多条数、分钟数）。
- **消息历史列表：新记录插入时整行「上下镜像」、行序错乱。**
  弹 toast 的调用方会用 `withAnimation`（`ToastManager.show` 内部就是），而历史写入与它
  发生在同一个 runloop 轮次，于是新记录的插入被卷进那个动画事务。macOS 上 SwiftUI 用
  「快照」渲染行的插入过渡，把翻转过的 AppKit 视图快照画回未翻转位图就会得到上下镜像的行；
  叠加动画被主线程阻塞/窗口遮挡冻住，坏状态会一直留在界面上。
  症状：最新收到的几条消息整行倒着显示，且顺序与时间对不上；早于它们的记录正常。
  修复：给历史界面加 `.transaction { $0.animation = nil }`，让列表永不参与动画
  （历史列表是日志，插入应当瞬时出现，本来也不需要过渡动画）。
  实测：修复前触发插入动画时逐帧抓图有 4 种不同画面；修复后 10 帧完全一致。

## [0.1.66] — 2026-09-21

### 新增

- **Toast 消息历史持久化**：每条 toast 自动落盘，App 重启后仍可查（`ToastHistoryStore`，存储 key `MySwiftAppTools.Toast.history.v1`）
- **消息浏览界面** `ToastHistoryView`：按时间倒序（新 → 旧）、一屏 20 条 + 底部「更多」翻页、按自然日分组吸顶、单条删除、批量清空（带二次确认）
- **独立窗口形态** `ToastHistoryWindowController.shared.show()`：供外部 App 一点菜单即弹历史窗口；也可用 `.sheet { ToastHistoryView() }` 嵌进自己的页面
- **统一配置入口** `ToastManager.shared.configureToastHistory(...)`：6 个参数全部可选，**省略即保持原值**，多次调用互不干扰
- **访问器** `ToastManager.shared.toastHistory`（旧名 `history` 保留为别名）
- **三重容量上限**：条数 500 / 单条 500 字符 / 总字节 512 KB，任一项触顶都从最旧丢弃
- **`ToastItem.createdAt`**：消息发出时间，随展示对象一并暴露
- **`ToastRecord`**：可持久化的历史模型（`id` / `message` / `type` / `position` / `createdAt`）
- **`ToastHistoryStore.record(message:type:)`**：只记历史、不弹提示
- **`ToastHistoryStore.reload()` / `flush()`**：App Group 跨进程刷新、延迟写盘手动落盘
- **DEBUG 预览样本** `ToastHistoryPreviewData`（42 条，覆盖分页边界、跨天分组、5 种类型与长文本）：仅在 Debug 编译，Release 不打包
- 单测 `ToastHistoryTests` 19 例 + 公开 API 冒烟用例 3 例

### 变更

- `ToastType` / `ToastPosition` 补充 `String` 原始值与 `Codable` / `Sendable` 一致性（**未新增任何 case**，外部穷举 `switch` 不受影响）
- `ToastHistoryStore.configure(...)` 及 6 个配置属性收为对内可写（`internal` / `public internal(set)`），对外只保留 `ToastManager.shared.configureToastHistory(...)` 一条配置路径；这两处 API 从未随任何已发布版本存在，不构成破坏
- Toast 全部源码归入 `Sources/MySwiftAppTools/Toast/`（SwiftPM 自动递归收录，`Package.swift` 无需改动）
- README 补充消息历史用法、「推荐初始化」新增历史配置示例
- `.gitignore` 清理失效的 `codex-plan/**` 规则，新增忽略 `.workbuddy/`

### 兼容性说明

- **源兼容**：老 App 不改一行代码即可升级。`ToastManager.configure(maxVisibleToasts:toastWidth:topPadding:bottomPadding:copyOnTap:)` 与 `show(...)` 的参数名、顺序、类型、默认值全部未变
- **行为变化（无感但有后果）**：升级后 toast 自动落盘，UserDefaults 多出 `MySwiftAppTools.Toast.history.v1`，典型 100 KB 量级。老 App 没有浏览入口，属于「只写不读」的静默开销；想彻底关掉加一行即可：

  ```swift
  ToastManager.shared.configureToastHistory(isHistoryEnabled: false)
  ```

- **隐私**：历史为明文，存于 `~/Library/Preferences/<bundleid>.plist`。toast 文本常含用户文件路径，在意的话用 `isHistoryEnabled` 或 `excludedTypes` 控制；配置了 App Group 时同 group 的 App 能读到同一份数据
- **硬红线**：本次**不得新增 `ToastType` case**。外部 App 只要有一处不带 `default` 的 `switch item.type`，加 case 就会当场编译失败。将来真要加，必须发 `0.2.0`

---

## [0.1.65] — 2026-08-29

- **变更** StoreManager 支持多产品 Pro 权益：同一个权益可由多个 StoreKit 产品共同授予，任一产品有效即 `hasPurchasedPro == true`

## [0.1.64] — 2026-07-22

- **移除** 设计系统拆分到独立包 `EasyDesignSystem`
- **变更** 完善对外 API

## [0.1.63] — 2026-06-04

- **移除** 国际化管理迁移至独立包 `SwiftHelpCenter`

## [0.1.62] — 2026-06-02

- **移除** 帮助中心与反馈模块迁移至独立包 `SwiftHelpCenter`

## [0.1.61] — 2026-05-27

- **修复** 赋权窗口支持指定父窗口，避免总是被其他窗口遮挡

## [0.1.60] — 2026-05-25

- **新增** 国际化支持选择语言的运行时控制能力

## [0.1.59] — 2026-05-21

- **新增** 帮助中心增加强调色
- **文档** 完善 README

## [0.1.58] — 2026-05-21

- **变更** 优化帮助中心组件

## [0.1.57] — 2026-05-20

- **新增** 帮助中心支持设置未读颜色

## [0.1.56] — 2026-05-20

- **变更** 优化帮助中心按钮尺寸

## [0.1.55] — 2026-05-20

- **变更** 优化帮助中心组件

## [0.1.54] — 2026-05-20

- **新增** 版本中心组件

## [0.1.53] — 2026-05-16

- **新增** 应用反馈组件 `FeedbackManager`

## [0.1.52] — 2026-05-15

- **变更** `ThemeManager` 国际化优化

## [0.1.51] — 2026-05-13

- **变更** 继续优化 `MultiSourceDownloader`，补充国际化

## [0.1.50] — 2026-05-13

- **变更** 优化多源下载工具类

## [0.1.49] — 2026-05-12

- **新增** 多源下载工具类 `MultiSourceDownloader`

## [0.1.48] — 2026-05-10

- **变更** 完善 `subtleFill` 颜色

## [0.1.47] — 2026-05-10

- **新增** `RCMGroup` 支持多种背景颜色

## [0.1.46] — 2026-05-09

- **变更** 完善 `DefaultsTools` 对外 API

## [0.1.45] — 2026-05-09

- **变更** `RCMPillTone` 增加颜色种类

## [0.1.44] — 2026-05-09

- **变更** `RCMPillFlow` 增加排序支持

## [0.1.43] — 2026-05-09

- **变更** 优化 `RCMPill`

## [0.1.42] — 2026-05-09

- **新增** `RCMPill` 组件

## [0.1.41] — 2026-05-09

- **变更** `RCMPageSection` 默认不带背景

## [0.1.40] — 2026-05-09

- **新增** `RCMGroup` 组件

## [0.1.39] — 2026-05-09

- **变更** `RCMCard` 默认不显示背景，需显式传入背景参数

## [0.1.38] — 2026-05-08

- **新增** `MyDirectoryType` 数据更新时发出通知

## [0.1.37] — 2026-05-07

- **变更** `MultilineSubtitleRow` 不再限制最小宽度

## [0.1.36] — 2026-05-07

- **变更** Toast 自定义图标颜色改为白色

## [0.1.35] — 2026-05-04

- **变更** 优化对外 API

## [0.1.34] — 2026-05-03

- **变更** 完善 `RCMComparisonSection` 国际化

## [0.1.33] — 2026-05-03

- **修复** 更正国际化文案

## [0.1.32] — 2026-05-03

- **变更** 新增组件的国际化

## [0.1.31] — 2026-05-03

- **新增** `ComparisonSection` / `RCMComparisonSection` 组件

## [0.1.30] — 2026-04-30

- **修复** `PlaceholderTextEditor` 与 `ReadOnlyTextView` 的调用问题

## [0.1.29] — 2026-04-30

- **变更** 优化颜色 API

## [0.1.28] — 2026-04-29

- **新增** 公开 `loadNormalDirectories` API

## [0.1.27] — 2026-04-29

- **修复** 权限（permission）管理缺陷

## [0.1.26] — 2026-04-29

- **变更** 更新 `RCMButton`，同步 README

## [0.1.25] — 2026-04-29

- **变更** 优化 `RCMBadge` 调用方式

## [0.1.24] — 2026-04-29

- **变更** 整体优化一轮

## [0.1.23] — 2026-04-28

- **变更** 完善 `RCMSidebarIconPresetTint`

## [0.1.22] — 2026-04-28

- **新增** `RCMBadge` 支持接收国际化字符串

## [0.1.21] — 2026-04-28

- **变更** 优化 `RCMTheme.shared.colors` 访问方式

## [0.1.20] — 2026-04-28

- **新增** `RCMBadge` 增加 `accent` 样式

## [0.1.19] — 2026-04-28

- **新增** 阴影与 `stroke` 支持

## [0.1.18] — 2026-04-28

- **变更** 完成颜色设置

## [0.1.17] — 2026-04-28

- **变更** 完善 DesignSystem

## [0.1.16] — 2026-04-27

- **变更** 更新 `RCMColor.primary` 调用方法

## [0.1.15] — 2026-04-27

- **新增** 每个 App 可自行配置主色系

## [0.1.14] — 2026-04-27

- **变更** 更新国际化

## [0.1.13] — 2026-04-27

- **新增** 国际化支持

## [0.1.12] — 2026-04-27

- **变更** 更新 `RCMHeroPanelBlue`

## [0.1.11] — 2026-04-27

- **修复** 纠正 `RCMHeroPanelBlue`

## [0.1.10] — 2026-04-27

- **变更** 更新 `RCMHeroPanel`

## [0.1.9] — 2026-04-27

- **新增** `HourglassView` 支持外部初始化

## [0.1.8] — 2026-04-27

- **新增** `HourglassView` 对外开放调用

## [0.1.7] — 2026-04-27

- **变更** `ProGatekeeper` 由静态调用改为单例调用

## [0.1.6] — 2026-04-27

- **修复** 修复 `ProGatekeeper` 调用问题

## [0.1.5] — 2026-04-27

- **变更** 放开 `ProGatekeeper.freeLimits` 访问权限

## [0.1.4] — 2026-04-27

- **修复** 解决 `EscCloseModifier` 无法调用的问题

## [0.1.3] — 2026-04-27

- **修复** 解决 `ThemeManager` 调用报错

## [0.1.2] — 2026-04-26

- **变更** `StoreManager` 的购买接口对外开放调用

## [0.1.1] — 2026-04-26

- **修复** 修正入口方法的 `public` 可见性，补充 README

## [0.1.0] — 2026-04-26

- **新增** 首个版本：包结构初始化，沉淀跨 App 复用的工具类与基础 UI 组件

---

## 维护约定

发新版本时按下面三步走：

1. 把 `[Unreleased]` 小节改成 `[x.y.z] — YYYY-MM-DD`，并补一个新的空 `[Unreleased]`
2. 条目按「新增 / 变更 / 修复 / 移除 / 文档」归类；破坏性变更单独加 **BREAKING** 标注与迁移说明
3. 有破坏性变更 → 版本号进到 `0.2.0`（`0.x` 阶段 minor 位承载破坏性变更）；仅新增或修复 → `0.1.x` 递增

判断某次改动是否源兼容的实证做法：在临时目录建一个消费包，写满老版本对外的调用形式，`rm -rf .build` 后干净重建，看是否零错误通过。
