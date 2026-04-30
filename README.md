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
| `RCMText.swift` | 文本组件 | 页面标题、章节标题、标签文字、说明文字、等宽文字 |
| `RCMButtons.swift` | 按钮组件 | 按钮样式、侧边栏图标、徽章、开关 |
| `RCMSurfaces.swift` | 容器组件 | 卡片、分区、Hero 面板、侧边栏、折叠面板、多行行 |
| `RCMRows.swift` | 行组件 | 设置行、键值行、带标签的内联字段 |
| `RCMDesignSystemPreview.swift` | 预览工具 | Design Token 可视化编辑器，可调整并导出 JSON |

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
- `RCMButton`
- `RCMPrimaryButtonStyle`
- `RCMSecondaryButtonStyle`
- `RCMSoftButtonStyle`
- `RCMDangerButtonStyle`
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
- `RCMPageSection`
- `RCMHeroPanel`
- `MultilineSubtitleRow`
- `CollapsibleSection`

快速页面示例：

```swift
VStack(alignment: .leading, spacing: RCMTheme.shared.spacing.xl) {
    RCMPageTitle("目录权限设置", subtitle: "请选择文件复制功能使用的目标目录。")

    RCMPageSection("已授权目录") {
        RCMSettingRow("Documents", subtitle: "/Users/name/Documents") {
            RCMBadge("已授权", style: .success)
        }
    }

    HStack(spacing: RCMTheme.shared.spacing.md) {
        RCMButton("新增", role: .primary, systemImage: "plus") {
            add()
        }
        RCMButton("删除", role: .soft, systemImage: "trash") {
            remove()
        }
    }
}
.padding(RCMTheme.shared.spacing.xxl)
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

容器组件：

```swift
RCMCard {
    Text("卡片内容")
}

RCMCard(background: Color.red.opacity(0.1)) {
    Text("红色调卡片")
}

RCMPageSection("存储管理") {
    RCMValueRow("已用空间", value: "12.4 GB")
    RCMValueRow("剩余空间", value: "86.1 GB", tone: .green)
}

RCMHeroPanel {
    VStack(alignment: .leading) {
        Text("欢迎使用").font(.title).foregroundColor(.white)
        Text("当前面板会跟随 RCMTheme 的 heroGradient 和 shadow")
            .foregroundColor(.white.opacity(0.8))
    }
}
```

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

建议迁移路径：

1. 新项目优先使用 `RCMTheme + DesignSystem`。
2. 旧项目先从 Purchase、About、Settings 这类简单页面替换按钮、标题、卡片。
3. 再逐步把 `ThemeManager.swift` 中真正通用的组件迁移到 DesignSystem。
4. `ThemeManager.swift` 作为 legacy 兼容层保留，不建议继续在里面扩展新 UI 能力。

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
