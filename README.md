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

建议在 App 启动阶段集中配置用到的工具。下面是一个较完整的初始化模板：用得到的保留，用不到的删掉即可。

```swift
import SwiftUI
import MySwiftAppTools

@main
struct YourApp: App {
    init() {
        // UserDefaults。如果 App 和扩展需要共享数据，传 appGroupID；否则可以不配置。
        DefaultsTools.configure(appGroupID: "group.com.yourcompany.yourapp")

        // Keychain 默认 service。建议每个 App 使用自己的 service 名。
        KeychainTools.configure(defaultService: "YourApp")

        // 统一日志 subsystem。
        Log.configure(subsystem: "com.yourcompany.yourapp")

        // Toast 全局配置。只有使用 ToastView / ShowToast 时才需要。
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

常见取舍：

- 不需要 App Group：可以不调用 `DefaultsTools.configure(...)`；默认使用 `UserDefaults.standard`。如需在运行时恢复 standard，可传入 `nil`。
- 不使用 Toast：可以不配置 `ToastManager`，也不需要挂 `ToastView()`。
- 不需要快速入口或 FAQ：`quickLinks` / `faqItems` 可以不传，对应区域不会显示。
- 需要 App 内语言切换：建议使用 SwiftHelpCenter 提供的 `SHCAppLanguageManager` / `SHCLocalization`，MySwiftAppTools 不再维护运行时语言偏好。

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

恢复使用 App 自身的 standard 配置：

```swift
DefaultsTools.configure(appGroupID: nil)
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

#### 本地化辅助函数

MySwiftAppTools 保留轻量本地化辅助函数，用于标准 Bundle 查表：

```swift
L("menu_new_file")
"menu_new_file".toNSLocalizedString
packageL(MySwiftAppToolsL10n.confirmOK)
"Toast.confirmOK".toPackageNSLocalizedString
```

这些入口会分别从 App 的 `Bundle.main` 或 MySwiftAppTools 的 `Bundle.module` 查表。

如果需要“跟随系统 / 简体中文 / English”这类 App 内语言切换，请使用 SwiftHelpCenter 中的 `SHCAppLanguageManager`、`SHCLocalization` 和 `.SHCAppLanguage(...)`。

注意事项：

- App 自己的业务文案仍放在 App 自己的 `Localizable.strings` 中，并通过 `defaultBundle: .main` 查表。
- MySwiftAppTools 自带 UI 文案使用 `packageL(...)` 或 `.toPackageNSLocalizedString`，从 `Bundle.module` 查表。
- 如果主 App 与 FinderSync / Share Extension 需要共享语言选择，请在 SwiftHelpCenter 中用 App Group 配置语言管理器。

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

### 用户沟通与 Legacy UI

#### HelpCenter / Feedback

帮助中心、反馈、公告、评分和 App 内语言切换能力已经迁移到 SwiftHelpCenter。

MySwiftAppTools 现在只保留业务无关的工具、存储、日志、下载、Keychain、Toast 和少量 Legacy UI。DesignSystem 已迁移到独立的 EasyDesignSystem 包。需要用户沟通相关能力时，请在 App 中直接引入 SwiftHelpCenter，并使用 `SHCHelpCenterManager`、`FeedbackManager`、`SHCAppLanguageManager` 等 `SHC` API。

#### `ThemeManager.swift`

历史项目中沉淀的 UI 辅助组件集合，包含：

- `ThemeManager`
- `Theme`
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
