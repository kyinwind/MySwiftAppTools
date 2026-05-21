# MySwiftAppTools

MichaelDevStudio 的 Swift/macOS 公共工具包，用来沉淀多个 App 中重复使用的工具类、基础 UI 组件和业务无关的通用能力。

这个包目前面向 macOS App，最低平台为 macOS 14，使用 Swift 6。

## 安装

在 Xcode 中添加 Swift Package：

```text
File > Add Package Dependencies...
```

开发联调时可以使用本地路径：

```text
/Users/yangxuehui/Documents/dev/MySwiftAppTools
```

正式项目建议使用 GitHub 仓库 + tag 版本，例如：

```text
Up to Next Major Version: 0.2.0
```

使用时在 App 代码中导入：

```swift
import MySwiftAppTools
```

## 推荐初始化

不同 App 可以在启动时集中配置这些工具：

```swift
@main
struct YourApp: App {
    init() {
        DefaultsTools.configure(appGroupID: "group.com.yourcompany.yourapp")
        KeychainTools.configure(defaultService: "YourApp")
        Log.configure(subsystem: "com.yourcompany.yourapp")

        RCMTheme.shared.applyPreset(.blue)

        ToastManager.shared.configure(
            maxVisibleToasts: 5,
            toastWidth: 420,
            copyOnTap: true
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .overlay(ToastView())
        }
    }
}
```

如果某个 App 不需要 App Group，可以不调用 `DefaultsTools.configure(...)`。

`RCMTheme` 建议在 App 启动阶段、UI 创建前完成配置。当前主题系统主要面向启动时配置；运行时动态切换主题时，SwiftUI 不一定自动刷新所有已经渲染的视图。

## 工具清单

### 存储与配置

#### `DefaultsTools`

`UserDefaults` 统一读写工具，支持 App Group。

常用能力：

- `DefaultsTools.configure(appGroupID:)`
- `DefaultsTools.shared`
- `set/value/remove/exists`
- `bool/int/double/float/string`
- `data/date/url`
- `stringArray/array/dictionary`
- `setCodable/codable`
- `DefaultsTools.Key(rawValue:)`
- 直接使用 string key 的便捷方法

示例：

```swift
DefaultsTools.configure(appGroupID: "group.com.yourcompany.yourapp")

let key = DefaultsTools.Key(rawValue: "launchCount")
let count = DefaultsTools.shared.int(key) ?? 0
DefaultsTools.shared.set(count + 1, for: key)
```

更多类型：

```swift
DefaultsTools.shared.set(Date(), for: "lastOpenDate")
let lastOpenDate = DefaultsTools.shared.date("lastOpenDate")

DefaultsTools.shared.set(URL(fileURLWithPath: "/tmp"), for: "lastFolder")
let lastFolder = DefaultsTools.shared.url("lastFolder")

DefaultsTools.shared.set(["png", "jpg"], for: "recentExtensions")
let recentExtensions = DefaultsTools.shared.stringArray("recentExtensions")

DefaultsTools.shared.set(["count": 3], for: "stats")
let stats = DefaultsTools.shared.dictionary("stats", as: Int.self)

struct UserPreference: Codable {
    var name: String
}

DefaultsTools.shared.setCodable(UserPreference(name: "Default"), for: "preference")
let preference = DefaultsTools.shared.codable(UserPreference.self, for: "preference")
```

#### `KeychainTools`

Keychain 通用封装。工具包不内置业务 account，调用 App 自己定义。

示例：

```swift
enum AppKeychainAccount: String {
    case openAIApiKey = "openai.apiKey"
    case azureApiKey = "AZURE_SPEECH_KEY"
}

KeychainTools.configure(defaultService: "YourApp")
KeychainTools.save("sk-xxx", account: AppKeychainAccount.openAIApiKey)
let key = KeychainTools.load(account: AppKeychainAccount.openAIApiKey)
```

### 日志与调试

#### `Log`

基于 `OSLog` 的轻量日志工具。

常用能力：

- `Log.configure(subsystem:isEnabled:)`
- `Log.debug/info/warn/error`
- `Log.log(category, level, message)`

示例：

```swift
Log.configure(subsystem: "com.yourcompany.yourapp", isEnabled: true)
Log.info("App started")
Log.log("Export", .error, "Export failed")
```

### 文件与网络

#### `MultiSourceDownloader`

多源备源下载工具，适用于模型文件的国内/国外镜像切换下载场景。

**核心能力：**

- 多 URL 备源：一个失败自动切换下一个
- 并发可访问性探测：启动时优先 HEAD，失败后用 `Range: bytes=0-0` 兜底
- 自动源选择：优先选择支持 Range 且响应更快的源
- 断点续传：支持 Range 请求，失败后重试从中断处继续
- 安全跨源策略：默认不在不同镜像之间复用临时文件，避免拼接出损坏文件
- 哈希校验：支持 SHA256、SHA1、MD5，下载完成后校验完整性
- 速度统计：实时计算下载速度和预估剩余时间
- 原子性替换：校验通过后才替换目标文件

**相关类型：**

```swift
MultiSourceDownloader
MultiSourceDownloader.Progress      // 进度信息
MultiSourceDownloader.Configuration // 下载配置
MultiSourceDownloader.HashAlgorithm // SHA256 / SHA1 / MD5
MultiSourceDownloader.DownloadError // 错误类型
```

**基本用法：**

```swift
let urls = [
    URL(string: "https://www.modelscope.cn/models/...")!,
    URL(string: "https://github.com/...")!
]

let destinationURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("Models")
    .appendingPathComponent("kokoro-v1.onnx")

let downloader = MultiSourceDownloader(
    urls: urls,
    destinationURL: destinationURL,
    hashAlgorithm: .sha256,
    expectedHash: "abc123def456...",
    configuration: .init(
        maxRetryCount: 3,
        requestTimeout: 30,
        probeTimeout: 6,
        allowsCrossSourceResume: false
    )
)

try await downloader.startDownload { progress in
    DispatchQueue.main.async {
        self.progressBar.value = progress.fractionCompleted
        self.speedLabel.stringValue = progress.formattedSpeed
        self.remainingLabel.stringValue = progress.formattedRemainingTime
    }
}
```

**Configuration 字段：**

| 字段 | 默认值 | 说明 |
|------|--------|------|
| `maxRetryCount` | `3` | 每个下载源的最大重试次数 |
| `requestTimeout` | `15` | 正式下载请求超时时间 |
| `probeTimeout` | `5` | 下载源可用性探测超时时间 |
| `allowsCrossSourceResume` | `false` | 是否允许不同源之间复用临时文件断点续传 |

`allowsCrossSourceResume` 默认关闭。即使两个 URL 文件名相同，也可能来自不同版本或不同压缩结果；跨源续传可能导致文件损坏。只有在你确认多个源内容完全一致，并且有 hash 校验兜底时，再考虑打开。

**简写方式（仅 SHA256）：**

```swift
let downloader = MultiSourceDownloader(
    urls: urls,
    destinationURL: destinationURL,
    expectedSHA256: "abc123def456..."
)
```

**Progress 字段：**

| 字段 | 类型 | 说明 |
|------|------|------|
| `fractionCompleted` | `Double` | 进度 0.0 - 1.0 |
| `downloadedBytes` | `Int64` | 已下载字节数 |
| `totalBytes` | `Int64` | 文件总大小 |
| `speed` | `Double` | 下载速度 (bytes/s) |
| `remainingSeconds` | `Double?` | 预估剩余秒数 |
| `formattedSpeed` | `String` | 格式化速度，如 "1.5 MB/s" |
| `formattedRemainingTime` | `String` | 格式化剩余时间，如 "1:30" |

**取消下载：**

```swift
let downloader = MultiSourceDownloader(...)
let task = Task {
    try await downloader.startDownload { ... }
}

Button("取消") {
    downloader.cancel()
}
```

**错误处理：**

```swift
do {
    try await downloader.startDownload { ... }
} catch MultiSourceDownloader.DownloadError.noValidUrls {
    ShowToastError("所有下载源都不可访问")
} catch MultiSourceDownloader.DownloadError.verificationFailed(let algo, let url, let expected, let actual) {
    ShowToastError("\(algo.displayName) 校验失败：\(url.lastPathComponent)")
} catch {
    ShowToastError("下载失败: \(error.localizedDescription)")
}
```

#### `FileTools`

文件系统工具，提供常见路径、文件判断、目录创建、复制、移动、删除、Finder 打开等能力。

常用能力：

- `documentsDirectory`
- `cachesDirectory`
- `applicationSupportDirectory`
- `temporaryDirectory`
- `exists/isDirectory/isWritable`
- `ensureDirectory/createFile/remove/copy/move`
- `openInFinder`
- `copyTextsToPasteboard`

示例：

```swift
let folder = FileTools.documentsPath("Exports")
try FileTools.ensureDirectory(folder)
FileTools.openInFinder(folder)
```

#### `DateTools`

日期格式化、日期差、月份计算、日期字符串转换等工具。

常用能力：

- `getStringByCurrentDate`
- `getDateTimeStringByCurrentDate`
- `getStringByDate`
- `getDateByString`
- `getDateDiff`
- `getDateAfterDays`
- `DateFormatter.zipName`

### 音频与提示

#### `AudioPlayer`

基于 `AVAudioPlayer` 的简单音频播放工具。

常用能力：

- `AudioPlayer.shared`
- `playAudio(forResource:ofType:rate:)`
- `play(url:rate:)`
- `loadAudio`
- `pause/stop`
- `playSystemSound`

示例：

```swift
AudioPlayer.shared.playSystemSound("Glass")
AudioPlayer.shared.play(url: audioURL)
```

#### `ToastManager` / `ToastView`

SwiftUI 全局 toast 提示工具。

使用方式：

```swift
ContentView()
    .overlay(ToastView())
```

然后在 MainActor 上调用：

```swift
ShowToast("普通提示")
ShowToastSuccess("保存成功")
ShowToastWarn("请先选择文件")
ShowToastError("操作失败")
ShowToast("处理中...", type: .loading)
ShowToastHide()
```

需要确认按钮：

```swift
ShowToast(
    "首次使用需要确认",
    customIcon: Image(systemName: "sparkles"),
    requireConfirm: true,
    onConfirm: {
        // 用户点击 OK 后执行
    }
)
```

### macOS 系统能力

#### `AutoLaunchManager`

macOS 登录时自动启动管理工具，基于 `SMAppService.mainApp`。适用于 macOS 13+；本工具包最低支持 macOS 14，所以不再兼容旧的 `LSSharedFileList` API。

常用能力：

- `AutoLaunchManager.shared.isEnabled`
- `AutoLaunchManager.shared.enable()`
- `AutoLaunchManager.shared.disable()`
- `AutoLaunchManager.shared.setEnabled(_:)`
- `AutoLaunchManager.shared.toggle()`

在设置页里绑定开关：

```swift
struct SettingsView: View {
    @State private var launchAtLogin = false

    var body: some View {
        Toggle("登录时自动启动", isOn: $launchAtLogin)
            .onAppear {
                launchAtLogin = AutoLaunchManager.shared.isEnabled
            }
            .onChange(of: launchAtLogin) { _, newValue in
                let success = AutoLaunchManager.shared.setEnabled(newValue)
                if !success {
                    launchAtLogin = AutoLaunchManager.shared.isEnabled
                    ShowToastError("自动启动设置失败")
                }
            }
    }
}
```

也可以在按钮里直接切换：

```swift
Button("切换自动启动") {
    if AutoLaunchManager.shared.toggle() {
        ShowToastSuccess("设置已更新")
    } else {
        ShowToastError("设置失败")
    }
}
```

注意：

- 这个能力需要在真实 macOS App bundle 中验证；Swift Package 测试 target 或命令行 demo 只能做编译验证。
- 用户也可以在系统设置的登录项里手动修改状态，所以设置页出现时建议重新读取 `AutoLaunchManager.shared.isEnabled`。

### 购买与 Pro 权限

#### `StoreManager`

StoreKit 购买状态管理工具。产品 ID 由调用 App 配置，工具包不写死任何业务产品。

示例：

```swift
enum AppProductID {
    static let pro = "com.yourcompany.yourapp.pro"
}

@State private var storeManager = StoreManager(
    productIDs: [AppProductID.pro],
    proProductID: AppProductID.pro
)

ContentView()
    .environment(storeManager)
```

购买页中：

```swift
ForEach(storeManager.products) { product in
    Button(product.displayPrice) {
        Task {
            await storeManager.purchase(product)
        }
    }
}
```

判断 Pro：

```swift
if storeManager.hasPurchasedPro {
    // 解锁 Pro 功能
}
```

#### `ProGatekeeper`

通用 Pro 功能与免费额度控制工具。具体 feature 由调用 App 自己定义。

示例：

```swift
enum AppProFeature: String {
    case privacyOCR
    case privacyAIRepair
    case batchExport
}

ProGatekeeper.shared.configure(
    freeLimits: [
        AppProFeature.privacyOCR: 10,
        AppProFeature.privacyAIRepair: 5,
        AppProFeature.batchExport: 0
    ],
    keyPrefix: "YourApp.ProGatekeeper",
    hasPurchasedPro: {
        storeManager.hasPurchasedPro
    },
    presentPurchase: {
        // 打开购买页
    }
)

if await ProGatekeeper.shared.check(AppProFeature.privacyOCR) {
    // 执行功能
}
```

说明：

- `freeLimits` 中没有声明的 feature，会被视为 Pro-only。
- limit 为 `0` 表示免费用户完全不可用。
- Pro 用户直接放行，不消耗免费次数。

### 沙盒权限

#### `PermissionManager`

macOS 沙盒目录授权和 security-scoped bookmark 管理工具。

默认情况下，`DirectoryManager` 会把授权目录和 bookmark 保存到 `UserDefaults.standard`。如果 App 有 Finder Extension、Share Extension 等扩展，并且主 App 与扩展需要共享同一份目录授权数据，请在主 App 和扩展启动时都配置同一个 App Group：

```swift
@main
struct YourApp: App {
    init() {
        DirectoryManager.configure(appGroupID: "group.com.yourcompany.yourapp")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

如果你已经自己创建了 `UserDefaults`，也可以直接传入：

```swift
let sharedDefaults = UserDefaults(suiteName: "group.com.yourcompany.yourapp")!
DirectoryManager.configure(userDefaults: sharedDefaults)
```

扩展里也要使用同一个 `groupID` 或同一个 suite。这样 `PermissionManager` 通过 `DirectoryManager` 保存的 bookmark 才能在主 App 和扩展之间共享。

相关类型：

- `PermissionPurpose`
- `PermissionUrlGroup`
- `PermissionManager`
- `DirectoryManager`
- `MyDirectory`
- `MyDirectoryType`

示例：

```swift
if let group = await PermissionManager.shared.ensureAccess(
    for: targetURL,
    purpose: .write
) {
    let accessURL = group.matchUrl
    if accessURL.startAccessingSecurityScopedResource() {
        defer { accessURL.stopAccessingSecurityScopedResource() }
        // 访问文件或目录
    }
}
```

### 组件流程联动

#### `ComponentsFlowManager`

用于管理一个页面中多个组件的联动关系，例如：

- 同组组件互斥
- 某组完成后解锁另一组
- 某个组件 busy 时禁用目标组件

相关类型：

- `ComponentsFlowManager`
- `ComponentState`
- `ComponentNode`
- `InteractionContext`
- `InteractionRule`
- `AnyInteractionRule`
- `GroupMutualExclusionRule`
- `GroupDependencyRule`
- `BusySourceDisablesTargetsRule`

示例：

```swift
enum ComponentID: String {
    case importFile
    case parse
    case export
}

enum GroupID: String {
    case input
    case output
}

let flow = ComponentsFlowManager<ComponentID, GroupID>(
    rules: [
        AnyInteractionRule(
            GroupDependencyRule(dependencies: [
                .output: [.input]
            ])
        )
    ]
)

flow.register(.importFile, groupID: .input)
flow.register(.export, groupID: .output)

let canExport = flow.isEnabled(.export)
```

### 基础 UI 与 Design System

#### `RCMTheme`

DesignSystem 的主题入口。所有 `RCMButton`、`RCMBadge`、`RCMCard`、`RCMPageSection`、`RCMHeroPanel` 等组件都会从 `RCMTheme.shared` 读取颜色、间距、字体、圆角、阴影等 token。

推荐在 App 启动时配置一次：

```swift
@main
struct YourApp: App {
    init() {
        RCMTheme.shared.applyPreset(.orange)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

内置预设：

- `.blue` / `.default`：通用蓝色主题
- `.orange` / `.rightClickMate`：通用橙色主题
- `.purple` / `.videoHero`：通用紫色主题

也可以用闭包按 App 微调：

```swift
RCMTheme.shared.configure { tokens in
    tokens.colors.primary = Color(hexRGB: "#FF6B00")
    tokens.colors.accent = Color(hexRGB: "#FF6B00")
    tokens.spacing.lg = 24
    tokens.radius.md = 10
    tokens.shadow = RCMShadowTokens(
        color: "#000000",
        opacity: 0.08,
        radius: 16,
        x: 0,
        y: 8
    )
}
```

如果想用 JSON 管理主题：

```swift
// 读取 App 自己 Bundle 里的 MyAppTheme.json
try RCMTheme.shared.configure(jsonResource: "MyAppTheme")

// 读取 Swift Package 内置的默认主题
try RCMTheme.shared.applyDefaultThemeFromPackage()

// 读取任意文件 URL
try RCMTheme.shared.configure(jsonFileURL: themeURL)
```

主题 JSON 可以只写需要覆盖的字段，缺失字段会自动使用默认 token：

```json
{
  "colors": {
    "primary": "#FF6B00",
    "accent": "#FF6B00"
  },
  "shadow": {
    "opacity": 0.08,
    "radius": 16
  }
}
```

常用读取方式：

```swift
RCMTheme.shared.colors.primary
RCMTheme.shared.spacing.md
RCMTheme.shared.radius.lg
RCMTheme.shared.typography.body
RCMTheme.shared.controlSize.buttonHeight
RCMTheme.shared.heroGradient.gradient
RCMTheme.shared.shadow.shadowColor
```

#### DesignSystem

位于 `Sources/MySwiftAppTools/DesignSystem`，提供一套基础 SwiftUI 组件。

核心思路是 Token 数据驱动：`RCMTheme` 持有统一 token，文本、按钮、卡片、行组件都会自动跟随主题。

文件总览：

| 文件 | 角色 | 说明 |
|------|------|------|
| `RCMDesignTokens.swift` | 数据层 | 颜色、间距、圆角、字体、渐变、阴影等 token |
| `RCMTheme.swift` | 配置层 | 全局主题单例、闭包配置、JSON 配置、预设主题、导出 JSON |
| `RCMDefaultTheme.json` | 资源文件 | 包内默认主题模板 |
| `RCMLayouts.swift` | 页面骨架 | 标准页面容器、页面内容栈 |
| `RCMText.swift` | 文本组件 | 页面标题、章节标题、标签文字、说明文字、等宽文字 |
| `RCMButtons.swift` | 按钮组件 | 按钮样式、侧边栏图标、徽章、开关 |
| `RCMSurfaces.swift` | 容器组件 | 卡片、分区、Hero 面板、侧边栏、折叠面板、多行行 |
| `RCMRows.swift` | 行组件 | 设置行、键值行、带标签的内联字段 |
| `RCMStates.swift` | 状态模式 | 空状态、错误状态、加载状态、进度面板 |
| `RCMDesignSystemPreview.swift` | 预览工具 | Design Token 可视化编辑器，可调整并导出 JSON |
| `RCMDesignSystemGallery.swift` | 组件展厅 | 用真实页面场景展示推荐 UI 组合 |

推荐按三层理解 DesignSystem：

| 层级 | 作用 | 例子 |
|------|------|------|
| Tokens | 视觉决策 | 颜色、字体、间距、圆角、阴影 |
| Layouts | 页面骨架 | 页面容器、内容栈、章节组织 |
| Primitives | 基础组件 | 按钮、徽章、文本、卡片、行 |
| Patterns | 页面模式 | 空状态、错误状态、加载状态、下载进度 |

主要内容：

- `RCMTheme`
- `RCMDesignTokens`
- `RCMPresetTheme`
- `RCMColorTokens`
- `RCMSpacingTokens`
- `RCMRadiusTokens`
- `RCMStrokeTokens`
- `RCMShadowTokens`
- `RCMTypographyTokens`
- `RCMControlSizeTokens`
- `RCMPage`
- `RCMPageStack`
- `RCMButton`
- `RCMPrimaryButtonStyle`
- `RCMSecondaryButtonStyle`
- `RCMSoftButtonStyle`
- `RCMDangerButtonStyle`
- `RCMFlowLayout`
- `RCMPill`
- `RCMPillFlow`
- `RCMSidebarIcon`
- `RCMBadge`
- `RCMToggle`
- `RCMPageTitle`
- `RCMSectionTitle`
- `RCMLabelText`
- `RCMCaptionText`
- `RCMMonoText`
- `RCMSettingRow`
- `RCMValueRow`
- `RCMInlineField`
- `RCMCard`
- `RCMGroup`
- `RCMPageSection`
- `RCMHeroPanel`
- `RCMEmptyState`
- `RCMErrorState`
- `RCMLoadingState`
- `RCMProgressPanel`
- `RCMDesignSystemGallery`
- `MultilineSubtitleRow`
- `CollapsibleSection`

推荐页面结构：

```text
RCMPage
└── RCMPageSection 可选
    └── RCMGroup
        ├── RCMSettingRow / RCMValueRow / RCMInlineField
        ├── RCMButton / RCMBadge / RCMToggle
        └── RCMEmptyState / RCMProgressPanel / 自定义内容
```

这套结构是 DesignSystem 当前推荐的主路径。新页面优先按这个层级搭建，通常不需要直接处理圆角、背景、行间距和按钮样式。

不过这不是强制模板。有些层是“推荐组件”，有些层是“可选组件”。页面足够简单时，可以跳过 `RCMPageSection`，直接在 `RCMPage` 里放 `RCMGroup`。

最佳实践速查表：

| 层级 | 组件 | 是否推荐 | 是否必选 | 什么时候用 | 什么时候可以跳过 | 默认视觉 |
|------|------|----------|----------|------------|----------------|----------|
| 页面骨架 | `RCMPage` | 推荐 | 通常必选 | 一个完整页面，外层没有现成滚动容器 | 外层已经有 `ScrollView`、`NavigationSplitView` detail 或自定义页面容器 | 默认透明，可选页面背景 |
| 页面内容栈 | `RCMPageStack` | 推荐 | 可选 | 只想复用标题、最大宽度、padding、section 间距 | 已经使用 `RCMPage`，因为 `RCMPage` 内部已经包含它 | 默认透明 |
| 页面章节 | `RCMPageSection` | 推荐 | 可选 | 页面有多个明确区域，例如“基础设置”“高级设置” | 页面只有一组内容，或内容自身已经足够明确 | 无背景、无边框，可选分割线 |
| 内容分组 | `RCMGroup` | 推荐 | 通常必选 | 把一组相关设置项、状态项、操作项放在一个浅色区域里 | 页面内容本身已经是特殊自定义容器，或需要完全无容器布局 | 浅背景、圆角、无边框 |
| 设置行 | `RCMSettingRow` | 推荐 | 可选 | 左侧标题说明，右侧放开关、按钮、状态 | 内容不是“设置行”语义，例如大段预览、自定义编辑器 | 默认透明 |
| 键值行 | `RCMValueRow` | 推荐 | 可选 | 展示只读信息，例如版本、路径、状态、用量 | 需要复杂交互控件时用 `RCMSettingRow` 或自定义布局 | 默认透明 |
| 内联字段 | `RCMInlineField` | 推荐 | 可选 | 标题 + 输入控件，例如 TextField、Picker | 输入控件需要更复杂布局 | 默认透明 |
| 状态模式 | `RCMEmptyState` / `RCMErrorState` / `RCMLoadingState` / `RCMProgressPanel` | 推荐 | 可选 | 空列表、错误重试、加载中、下载进度 | 页面没有状态反馈需求 | 由组件自己决定 |
| 底层容器 | `RCMCard` | 谨慎使用 | 可选 | 自定义预览块、特殊视觉容器、实现新的 pattern | 普通设置页和工具页优先用 `RCMGroup` | 默认无背景，显式传入才显示 |

为什么 `RCMPageSection` 和 `RCMGroup` 暂时不合并：

- `RCMPageSection` 是页面结构语义，用来告诉用户当前内容属于哪个章节。
- `RCMGroup` 是视觉分组语义，用来告诉用户这些控件彼此相关。
- 一个 section 里可以有多个 group，也可以没有 group。这样能避免“章节标题”和“视觉容器”绑死。

`RCMSettingRow` 默认不再自己绘制更深的背景。设置页里最稳定的层级是：`RCMGroup` 提供浅色底，row 只负责内容排列。只有未来出现“警告行、选中行、推荐项”这类特殊语义时，才应该给 row 增加单独的强调样式。

`RCMCard` 不属于推荐页面结构的主路径。它是更底层的视觉容器，适合做自定义预览块、实现新的 DesignSystem pattern，或者承载需要显式背景的特殊内容。普通设置页、工具页、状态页优先使用 `RCMGroup`。

快速页面示例：

```swift
RCMPage("目录权限设置", subtitle: "请选择文件复制功能使用的目标目录。") {
    RCMPageSection("已授权目录") {
        RCMGroup {
            RCMSettingRow("Documents", subtitle: "/Users/name/Documents") {
                RCMBadge("已授权", style: .success)
            }
        }
    }

    RCMPageSection("操作") {
        RCMGroup(style: .plain) {
            HStack(spacing: RCMTheme.shared.spacing.md) {
                RCMButton("新增", role: .primary, systemImage: "plus") {
                    add()
                }
                RCMButton("删除", role: .soft, systemImage: "trash") {
                    remove()
                }
            }
        }
    }
}
```

Token 类型：

| 类型 | 内容 |
|------|------|
| `RCMColorTokens` | primary / accent / success / warning / danger + 派生语义色 |
| `RCMSpacingTokens` | xxs 到 xxxl 的 8 级间距 |
| `RCMRadiusTokens` | sm / md / lg / xl 的 4 级圆角 |
| `RCMTypographyTokens` | hero / pageTitle / sectionTitle / body / caption / monoCaption 等 |
| `RCMControlSizeTokens` | buttonHeight / fieldHeight / rowMinHeight |
| `RCMStrokeTokens` | hairline |
| `RCMShadowTokens` | color / opacity / radius / x / y |
| `RCMHeroGradient` | startColor / endColor 渐变 |

颜色工具：

```swift
let color = Color(hexRGB: "#3185FF")
let hex = color.toHex()
```

为了避免 8 位 hex 的 alpha 顺序含义不清，`Color(hex:)` 已废弃不用。请按数据格式选择明确命名的入口：

```swift
// 普通 RGB：#RGB / #RRGGBB
let blue = Color(hexRGB: "#3185FF")

// Alpha 在前：#AARRGGBB
let argbRed = Color(hexARGB: "#FFFF0000")
let argbRed2 = Color(hex: "#FFFF0000", format: .argb)

// 图片标注、Canvas、部分设计工具常见格式：#RRGGBBAA
let rgbaRed = Color(hexRGBA: "#FF0000FF")
let rgbaRed2 = Color(hex: "#FF0000FF", format: .rgba)
```

这个区分很重要：`#FF0000FF` 如果按 `#AARRGGBB` 解析是蓝色，如果按 `#RRGGBBAA` 解析才是不透明红色。

页面骨架：

```swift
RCMPage("设置", subtitle: "管理应用偏好") {
    RCMPageSection("通用") {
        RCMGroup {
            RCMSettingRow("自动更新") {
                RCMToggle(isOn: $autoUpdate, label: "启用")
            }
        }
    }
}
```

如果外层已经有 `ScrollView`、`NavigationSplitView` 或自定义窗口容器，可以只使用内容栈：

```swift
RCMPageStack(title: "设置", subtitle: "管理应用偏好") {
    RCMPageSection("通用") {
        RCMGroup {
            RCMValueRow("版本", value: "1.0.0")
        }
    }
}
```

文本组件：

```swift
RCMPageTitle("设置", subtitle: "管理应用偏好")
RCMSectionTitle("通用")
RCMLabelText("用户名")
RCMCaptionText("仅支持英文")
RCMMonoText("/usr/local/bin")
```

按钮、徽章、开关：

```swift
RCMButton("保存", role: .primary, systemImage: "checkmark") {
    save()
}

RCMButton(.danger, action: delete) {
    Label("删除", systemImage: "trash")
}

Button("取消") {}
    .buttonStyle(RCMSoftButtonStyle())

let statusText = "已完成"
RCMBadge(statusText, style: .success)
RCMBadge(verbatim: "v1.0.0", style: .neutral)

RCMToggle(isOn: $isEnabled, label: "自动更新")
RCMToggle(isOn: $isEnabled, localizedLabel: "自动更新")
```

流式标签：

```swift
RCMPillFlow(
    ["2560x1600", "1920x1080", "50%", "200%"],
    sortOrder: .ascending,
    minItemWidth: 96,
    showsRemoveButton: true,
    onTap: { value in
        applyHistory(value)
    },
    onRemove: { value in
        deleteHistory(value)
    }
)
```

`sortOrder` 默认是 `.original`，保持传入顺序；也可以使用 `.ascending` 或 `.descending` 按字符串本地化排序。

`RCMPillFlow` 会自动换行显示标签，并按展示顺序从一组浅色背景中轮换取色。单个 pill 的文本默认居中，整个胶囊区域都可点击；删除按钮只在鼠标悬停时显示。

如果只想使用流式布局，也可以直接用底层布局：

```swift
RCMFlowLayout {
    ForEach(tags, id: \.self) { tag in
        Text(tag)
    }
}
```

容器组件：

```swift
// 页面章节：只负责章节标题和内容组织，本身没有背景和边框
RCMPageSection("存储管理") {
    RCMGroup {
        RCMValueRow("已用空间", value: "12.4 GB")
        RCMValueRow("剩余空间", value: "86.1 GB", tone: .green)
    }
}

// 如果内容自己已经有分组，PageSection 不会再额外套一层背景
RCMPageSection("高级设置", showsDivider: true) {
    RCMValueRow("已用空间", value: "12.4 GB")
    RCMValueRow("剩余空间", value: "86.1 GB", tone: .green)
}

// 内容分组：默认有浅背景和圆角，适合包裹一组设置项或状态项
RCMGroup("基础设置", subtitle: "常用选项") {
    RCMSettingRow("登录时自动启动") {
        RCMToggle(isOn: $launchAtLogin, label: "启用")
    }
}

// 需要更明确的边界时，可以打开边框
RCMGroup("高级设置", showsBorder: true) {
    RCMSettingRow("调试模式") {
        RCMToggle(isOn: $debugMode, label: "启用")
    }
}

// 默认只提供 padding，不绘制背景
RCMCard {
    Text("无背景内容")
}

// 显式传入 background 后才绘制背景和圆角
RCMCard(background: Color.red.opacity(0.1)) {
    Text("红色调卡片")
}

RCMHeroPanel {
    VStack(alignment: .leading) {
        Text("欢迎使用").font(.title).foregroundColor(.white)
        Text("当前面板会跟随 RCMTheme 的 heroGradient 和 shadow")
            .foregroundColor(.white.opacity(0.8))
    }
}
```

`RCMPage`、`RCMPageSection`、`RCMGroup`、`RCMCard` 的分工：

| 组件 | 语义 | 默认背景 | 默认边框 | 标题 |
|------|------|---------|---------|------|
| `RCMPage` | 页面骨架 | 无，可选开启 | 无 | 有 |
| `RCMPageSection` | 页面章节 | 无 | 无 | 有 |
| `RCMGroup` | 内容分组 | 浅背景 | 无，可选开启 | 可选 |
| `RCMCard` | 底层视觉容器 | 无，显式传入才显示 | 无 | 无 |

简单判断规则：

- 需要完整页面骨架：用 `RCMPage`。
- 需要一个章节标题：用 `RCMPageSection`。
- 需要把一组设置项放在浅色区域里：用 `RCMGroup`。
- 需要一个特殊视觉容器，且不符合 `RCMGroup` 的语义：用 `RCMCard`。

侧边栏：

```swift
@State private var selection = "home"

let menuItems = [
    RCMSidebarMenuItem(id: "home", label: "首页", icon: "house", tint: .blue),
    RCMSidebarMenuItem(id: "settings", label: "设置", icon: "gearshape", tint: .gray),
]

RCMSidebarGroupView(title: nil, items: menuItems, selection: $selection)
```

行组件：

```swift
RCMSettingRow("文档目录", subtitle: "/Users/name/Documents") {
    RCMBadge("已授权", style: .success)
}

RCMValueRow("版本号", value: "2.1.0")
RCMValueRow("磁盘用量", value: "89%", tone: .orange)

RCMInlineField("服务器地址") {
    TextField("https://...", text: $serverURL)
}
```

状态模式：

```swift
RCMEmptyState(
    systemImage: "tray",
    title: "暂无文件",
    message: "添加文件后会显示在这里。",
    actionTitle: "添加文件",
    actionSystemImage: "plus"
) {
    addFiles()
}

RCMErrorState(
    title: "加载失败",
    message: "请检查网络后重试。",
    actionTitle: "重试"
) {
    reload()
}

RCMLoadingState("正在处理", message: "这通常只需要几秒。")

RCMProgressPanel(
    "模型下载",
    subtitle: "LaMa.mlpackage.zip",
    fractionCompleted: progress,
    statusText: "正在选择最快的下载源...",
    actionTitle: "取消",
    actionSystemImage: "xmark"
) {
    cancelDownload()
}
```

状态模式是 DesignSystem 的 Patterns 层，推荐用于空列表、加载中、下载模型、错误重试等常见页面片段。调用方只提供语义内容和动作，视觉层级、间距、按钮样式由 DesignSystem 统一决定。

折叠面板和多行行：

```swift
CollapsibleSection("高级选项") {
    Toggle("启用调试模式", isOn: $debugMode)
}

MultilineSubtitleRow(
    systemIcon: "folder",
    iconColor: .blue,
    title: "项目目录",
    subtitle: "这是一个很长的描述文字，可以换行显示"
) {
    Button("更改") {}
}
```

可视化编辑器：

```swift
RCMDesignSystemPreview()
```

`RCMDesignSystemPreview` 可以预览组件、调整 token，并导出 JSON。它目前仍在主 library target 中，适合作为内部开发工具使用。

组件展厅：

```swift
RCMDesignSystemGallery()
```

`RCMDesignSystemGallery` 用真实页面场景展示推荐组合，包括标准页面、状态模式、基础控件、行与标签、容器分层。它不是 token 编辑器，而是用来检查 DesignSystem 的默认 UI 效果是否足够好。

建议迁移路径：

1. 新项目优先使用 `RCMTheme + DesignSystem`。
2. 旧项目先从 Purchase、About、Settings 这类简单页面替换按钮、标题、卡片。
3. 再逐步把 `ThemeManager.swift` 中真正通用的组件迁移到 DesignSystem。
4. `ThemeManager.swift` 作为 legacy 兼容层保留，不建议继续在里面扩展新 UI 能力。

#### HelpCenter

位于 `Sources/MySwiftAppTools/HelpCenter`。

`DesignSystem` 是 UI 原料，提供按钮、行、分组、页面骨架等基础组件；`HelpCenter` 是用这些原料组合出来的功能模块，带有自己的数据模型、状态管理和业务流程。它更像一份可直接放进 App 的“预制组件”。

文件总览：

| 文件 | 角色 | 说明 |
|------|------|------|
| `RCMHelpCenter.swift` | 帮助中心 | 帮助按钮、未读红点、快速入口、版本历史、FAQ |

主要内容：

- `RCMVersionHistoryItem`
- `RCMHelpVideoLinks`
- `RCMHelpQuickLinkItem`
- `RCMHelpFAQItem`
- `RCMHelpCenterManager`
- `RCMHelpButton`
- `RCMVersionHistoryListView`

推荐结构：

| 区域 | 作用 | 配置来源 |
|------|------|----------|
| 顶部 | 帮助中心标题、技术支持、标记已读 | `supportURL`、未读状态 |
| 快速入口 | 教程、反馈、评分、官网等常用入口 | `quickLinks`，也可自动接入 `FeedbackManager` |
| 版本历史 | 完整版本更新记录和 Bilibili/YouTube 视频入口 | `items` |
| 常见问题 | 可折叠 FAQ | `faqItems` |

配置帮助中心：

```swift
let items = [
    RCMVersionHistoryItem(
        versionName: "v1.1.5",
        publishedAtString: "2026-05-15",
        changes: L("VersionHistory.v1_1_5.changes"),
        videoTitle: L("VersionHistory.v1_1_5.videoTitle"),
        bilibiliURL: URL(string: "https://www.bilibili.com/video/xxx"),
        youtubeURL: URL(string: "https://www.youtube.com/watch?v=xxx")
    )
].compactMap { $0 }

let quickLinks = [
    RCMHelpQuickLinkItem(
        title: L("HelpCenter.guide"),
        subtitle: L("HelpCenter.guide.subtitle"),
        systemImage: "book",
        url: URL(string: "https://example.com/guide")!
    ),
    RCMHelpQuickLinkItem(
        title: L("HelpCenter.videoTutorials"),
        systemImage: "play.rectangle",
        url: URL(string: "https://www.youtube.com")!
    )
]

let faqItems = [
    RCMHelpFAQItem(
        question: L("FAQ.getStarted.question"),
        answer: L("FAQ.getStarted.answer")
    ),
    RCMHelpFAQItem(
        question: L("FAQ.restorePurchase.question"),
        answer: L("FAQ.restorePurchase.answer")
    )
]

RCMHelpCenterManager.shared.configure(
    items: items,
    storageKey: "TTSMate.helpCenter.lastViewedPublishedAt",
    supportURL: URL(string: "https://example.com/support"),
    quickLinks: quickLinks,
    faqItems: faqItems,
    unreadColor: .red
)
```

如果 App 已经配置了 `FeedbackManager`，帮助中心会默认在快速入口中补充：

- `反馈问题`：点击后打开标准 macOS 反馈窗口 `FeedbackView`
- `给应用评分`：点击后打开 Mac App Store 评分页

示例：

```swift
FeedbackManager.shared.configure(
    appleID: "123456789",
    supportURL: "https://example.com/support",
    appName: "YourApp"
)
```

如果不希望自动加入反馈和评分入口，可以关闭：

```swift
RCMHelpCenterManager.shared.configure(
    items: items,
    storageKey: "YourApp.helpCenter.lastViewedPublishedAt",
    includeDefaultFeedbackLinks: false
)
```

主界面放帮助按钮：

```swift
RCMHelpButton()
```

`RCMHelpButton` 会根据 `RCMHelpCenterManager.shared.hasUnreadUpdates` 自动显示红点。点击后默认打开一个标准 macOS 窗口，带关闭、最小化和缩放按钮；不需要调用方再用 `.sheet` 包一层。

`RCMHelpButton` 默认使用适合 toolbar 的尺寸。如果要放在普通页面里，可以使用大号按钮：

```swift
RCMHelpButton(size: .large)
```

如果需要自己控制打开行为，也可以传入 action：

```swift
RCMHelpButton {
    RCMHelpCenterWindowPresenter.shared.show()
}
```

`RCMVersionHistoryListView` 中每条未读版本记录也会显示红点和 `New` 标记。

未读判断只看版本发布时间：

```swift
item.publishedAt > lastViewedPublishedAt
```

用户点击某条版本记录的 `Bilibili` 或 `YouTube` 后，组件会调用 `markAsRead(_:)`，把 `lastViewedPublishedAt` 更新到这条记录的发布时间。下次发布新版本时，只要新记录的 `publishedAt` 更晚，主界面帮助按钮和对应版本记录就会重新显示红点。

如果某条版本记录没有传 `bilibiliURL` 或 `youtubeURL`，这一条不会显示视频平台按钮。顶部的“标记为已读”按钮可以用于没有培训视频的版本记录，用户点击后会清除所有当前未读红点。

如果 `configure` 传入了 `supportURL`，版本历史窗口右上角会显示“打开技术支持”按钮。

未读提示颜色也可以通过 `configure` 统一配置，默认是红色。这个颜色会同步用于主界面帮助按钮红点、版本记录红点、以及 `New` 标签：

```swift
RCMHelpCenterManager.shared.configure(
    items: items,
    storageKey: "TTSMate.helpCenter.lastViewedPublishedAt",
    supportURL: URL(string: "https://example.com/support"),
    unreadColor: .blue
)
```

首次配置时，`markExistingItemsAsReadOnFirstConfigure` 默认是 `true`。这表示新安装或第一次接入组件时，不会把所有历史版本都显示成未读；之后 App 升级新增更晚的版本记录，才会显示红点。如果希望第一次打开也提示最新版本内容，可以设为 `false`：

```swift
RCMHelpCenterManager.shared.configure(
    items: items,
    storageKey: "TTSMate.helpCenter.lastViewedPublishedAt",
    markExistingItemsAsReadOnFirstConfigure: false
)
```

如果 App 和扩展需要共享红点状态，可以传入 App Group 的 `UserDefaults`：

```swift
let groupDefaults = UserDefaults(suiteName: "group.com.michaeldev") ?? .standard

RCMHelpCenterManager.shared.configure(
    items: items,
    storageKey: "RightClickMate.helpCenter.lastViewedPublishedAt",
    supportURL: URL(string: "https://example.com/support"),
    unreadColor: .orange,
    defaults: groupDefaults
)
```

国际化边界：

- 组件固定 UI 文案由 MySwiftAppTools 负责国际化，例如“帮助”“帮助中心”“快速入口”“版本历史”“常见问题”“暂无版本历史”。
- 版本号、更新内容、视频标题、快速入口标题、FAQ 问答属于具体 App 的业务内容，调用方负责国际化后再传入。
- `publishedAt` 使用 `Date` 保存，显示时由组件按当前系统语言和地区格式化。

#### `ThemeManager.swift`

历史项目中沉淀的 UI 辅助组件集合，包含：

- `ThemeManager`
- `Theme`
- `Color(hexRGB:)`
- `Color(hexARGB:)`
- `Color(hexRGBA:)`
- `CustomGroupBoxStyle`
- `CustomButtonStyle`
- `PlaceholderTextEditor`
- `ReadOnlyTextView`
- `CustomTextView`
- `EscCloseModifier`
- `ToobarStatusLight`
- `MySettingsCard`
- `ActionBar`
- `ActionItem`
- `ActionShortcut`
- `ActionBarButtonDisplayStyle`
- `AppInfo`

示例：

```swift
ActionBar(items: [
    .save(shortcut: .commandS) {
        save()
    },
    .delete {
        delete()
    }
])
```

#### `HourglassView`

沙漏动画视图，可用于等待、处理中或计时场景。

示例：

```swift
HourglassView()
```

## 国际化

工具包自带基础国际化资源：

```text
Sources/MySwiftAppTools/Resources/en.lproj/Localizable.strings
Sources/MySwiftAppTools/Resources/zh-Hans.lproj/Localizable.strings
```

包内文案通过 `Bundle.module` 读取，不依赖调用 App 的 `Localizable.strings`。

外部调用常用入口：

```swift
L("Some.Key")
"Some.Key".toNSLocalizedString
```

App 自己的业务文案建议仍放在 App 自己的本地化文件中。

## `FeedbackManager`

多通道用户反馈管理器，支持将反馈发送到 **Discord**、**钉钉机器人**、**邮箱** 三个渠道。

### 功能特性

- 支持 Discord Webhook（纯文本 + 文件上传）
- 支持钉钉机器人（纯文本）
- 支持邮件（通过 `mailto:` 打开系统邮件客户端）
- 内置系统信息收集（App 名称、版本、macOS 版本、CPU 类型等）
- 内置 App Store 评分跳转
- 开箱即用的 SwiftUI 反馈视图
- 中英文国际化支持

### 配置

在 App 启动时调用一次 `configure`：

```swift
import MySwiftAppTools

// 在 App.init() 中
FeedbackManager.shared.configure(
    appleID: "6752127439",           // Mac App Store 应用 ID（必填）
    supportURL: "https://...",       // 技术支持页面 URL（必填）
    email: "your@email.com",         // 接收反馈的邮箱（可选，有默认值）
    discordWebhook: "https://...",   // Discord Webhook URL（可选，有默认值）
    dingTalkWebhook: "https://...",  // 钉钉机器人 Webhook URL（可选，有默认值）
    appName: "MyApp"                 // 应用名称，用于系统信息（可选）
)
```

其中 `email`、`discordWebhook`、`dingTalkWebhook` 均有默认值，通常无需传入。

### 发送反馈

使用 `FeedbackPayload` 构造反馈内容，调用 `sendFeedback`：

```swift
let payload = FeedbackPayload(
    content: "这里填写反馈内容",
    attachments: [],                 // 附件 URL 列表
    includeSystemInfo: true,
    channels: [.discord]             // 发送渠道
)

Task {
    do {
        try await FeedbackManager.shared.sendFeedback(payload)
        print("发送成功")
    } catch {
        print("发送失败: \(error)")
    }
}
```

### 使用内置反馈视图

```swift
import MySwiftAppTools

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink("意见反馈") {
                    FeedbackView()
                }
            }
        }
    }
}
```

### 评分跳转

```swift
guard let config = FeedbackManager.shared.config else { return }
AppStoreHelper.rateApp(appleID: config.appleID)
```

### API 概览

| API | 说明 |
|-----|------|
| `FeedbackManager.shared.configure(...)` | 配置管理器（必调） |
| `FeedbackManager.shared.sendFeedback(_:)` | 发送反馈 |
| `FeedbackManager.shared.isSending` | 发送状态 |
| `FeedbackView()` | 内置反馈表单视图 |
| `AppStoreHelper.rateApp(appleID:)` | 打开 Mac App Store 评分页 |
| `SystemInfoProvider.collect(appName:)` | 收集系统信息 |
| `FeedbackConfiguration` | 配置数据结构 |
| `FeedbackChannel` | 反馈渠道枚举（discord / dingTalk / mail） |
| `FeedbackPayload` | 反馈内容数据模型 |

## 版本发布流程

建议每次给其他 App 使用前打 tag。

```bash
cd /Users/yangxuehui/Documents/dev/MySwiftAppTools
git status
git add .
git commit -m "Update reusable app tools"
git tag 0.2.0
git push origin main
git push origin 0.2.0
```

其他 App 更新包时：

```text
File > Packages > Update to Latest Package Versions
```

如果使用精确版本，需要在 Xcode 的 Package Dependencies 中手动改到新 tag。

## 维护原则

- 工具包不写死具体 App 的业务 ID、产品 ID、URL Scheme 或功能枚举。
- 具体业务信息通过 `configure(...)`、闭包或调用 App 自己定义的 enum 注入。
- 对外使用的类型、初始化器、方法必须是 `public`。
- 内部 helper、preview、demo 可以保持 `internal` 或 `private`。
- 修改工具包后，至少运行：

```bash
swift build
swift test
```

如果改了对外 API，建议再建一个外部 consumer 临时验证 `import MySwiftAppTools` 后能否正常调用。
