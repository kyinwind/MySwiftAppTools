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

## 工具清单

### 存储与配置

#### `DefaultsTools`

`UserDefaults` 统一读写工具，支持 App Group。

常用能力：

- `DefaultsTools.configure(appGroupID:)`
- `DefaultsTools.shared`
- `set/value/remove/exists`
- `bool/int/double/string`
- `DefaultsTools.Key(rawValue:)`
- 直接使用 string key 的便捷方法

示例：

```swift
DefaultsTools.configure(appGroupID: "group.com.yourcompany.yourapp")

let key = DefaultsTools.Key(rawValue: "launchCount")
let count = DefaultsTools.shared.int(key) ?? 0
DefaultsTools.shared.set(count + 1, for: key)
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

### 文件与日期

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

ProGatekeeper.configure(
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

if await ProGatekeeper.check(AppProFeature.privacyOCR) {
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

#### DesignSystem

位于 `Sources/MySwiftAppTools/DesignSystem`，提供一套基础 SwiftUI 组件。

主要内容：

- `RCMColor`
- `RCMSpacing`
- `RCMRadius`
- `RCMStroke`
- `RCMShadow`
- `RCMTypography`
- `RCMControlSize`
- `RCMButtonStyle`
- `RCMSidebarIcon`
- `RCMStatusBadge`
- `RCMStatBadge`
- `RCMPageTitle`
- `RCMSectionTitle`
- `RCMLabelText`
- `RCMCaptionText`
- `RCMMonoText`
- `RCMSettingRow`
- `RCMValueRow`
- `RCMInlineField`
- `RCMCard`
- `RCMPageSection`
- `RCMHeroPanel`
- `MultilineSubtitleRow`
- `CollapsibleSection`

示例：

```swift
RCMPageTitle("Settings", subtitle: "Manage app preferences")

RCMCard {
    RCMSettingRow("Enable Feature", subtitle: "Optional helper text") {
        Toggle("", isOn: $enabled)
    }
}

Button("Save") {
    save()
}
.rcmButton(.primary)
```

#### `ThemeManager.swift`

历史项目中沉淀的 UI 辅助组件集合，包含：

- `ThemeManager`
- `Theme`
- `Color(hex:)`
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
```

如果改了对外 API，建议再建一个外部 consumer 临时验证 `import MySwiftAppTools` 后能否正常调用。
