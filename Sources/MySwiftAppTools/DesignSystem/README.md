# RCM Design System

> 一套为 macOS SwiftUI 应用打造的**配置式**设计系统。  
> 核心思路：**Token 数据驱动 + 组件自动跟随**——改 Token 就能全局换肤。

---

## 📁 文件总览

| 文件 | 角色 | 一句话说明 |
|------|------|-----------|
| **RCMDesignTokens.swift** | 数据层 | 所有设计 Token 的数据结构定义（颜色、间距、圆角、字体、渐变等） |
| **RCMTheme.swift** | 配置层 | 全局主题单例：闭包配置 / JSON 配置 / 预设主题 / 导出 JSON |
| **RCMDefaultTheme.json** | 资源文件 | 默认 Token 值的 JSON 模板，可独立编辑或作为 `configure(jsonResource:)` 的输入 |
| **RCMText.swift** | 文本组件 | 页面标题、章节标题、标签文字、说明文字、等宽文字 |
| **RCMButtons.swift** | 按钮组件 | 4 种按钮样式 + 图标徽章 + 状态标签 + 开关 |
| **RCMSurfaces.swift** | 容器组件 | 卡片、分区卡片、Hero 面板、侧边栏、折叠面板、多行行 |
| **RCMRows.swift** | 行组件 | 设置行、键值行、带标签的内联字段 |
| **RCMDesignSystemPreview.swift** | 预览工具 | Design Token 可视化编辑器（预览 + 调整 + 导出 JSON） |

---

## 🏗️ 架构关系

```
┌─────────────────────────────────────────────┐
│              RCMTheme (单例)                 │
│   configure{} │ configure(json) │ applyPreset│
└──────────────┬──────────────────────────────┘
               │ 提供统一 Token
       ┌───────┼───────────┬───────────┐
       ▼       ▼           ▼           ▼
   RCMText  RCMButtons  RCMSurfaces  RCMRows
   (文本)    (按钮)      (容器)      (行组件)
```

**原则**：所有 UI 组件通过 `RCMTheme.shared` 读取 Token，不硬编码任何颜色/字号/间距。

---

## 🚀 快速上手

### 第一步：在 App 启动时配置主题

```swift
// 方式 A：使用预设（推荐）
RCMTheme.shared.applyPreset(.orange)

// 方式 B：闭包微调
RCMTheme.shared.configure { tokens in
    tokens.colors.primary = Color(hex: "#FF6B00")
    tokens.spacing.lg = 24
}

// 方式 C：从 JSON 文件加载
try? RCMTheme.shared.applyDefaultThemeFromPackage()
```

### 第二步：直接用组件写页面

```swift
VStack(alignment: .leading, spacing: RCMTheme.shared.spacing.xl) {
    // 1️⃣ 页面标题（来自 RCMText.swift）
    RCMPageTitle("目录权限设置", subtitle: "请选择文件复制功能使用的目标目录。")

    // 2️⃣ 分区卡片（来自 RCMSurfaces.swift）
    RCMPageSection("已授权目录") {
        // 设置行（来自 RCMRows.swift）
        RCMSettingRow("Documents", subtitle: "/Users/name/Documents") {
            RCMBadge("已授权", style: .success)
        }
    }

    // 3️⃣ 按钮（来自 RCMButtons.swift）
    HStack(spacing: RCMTheme.shared.spacing.md) {
        RCMButton(.primary, action: {}) {
            Text("新增")
        }
        RCMButton(.soft, action: {}) {
            Text("删除")
        }
        RCMButton("保存", role: .primary, systemImage: "checkmark") {
            save()
        }
    }
}
.padding(RCMTheme.shared.spacing.xxl)
```

---

## 📖 各文件详细用法

### 1. RCMDesignTokens.swift — Token 数据结构

**不需要你手动调用**，它是 `RCMTheme` 的数据载体。了解即可：

| 结构体 | 包含内容 |
|--------|---------|
| `RCMColorTokens` | primary / accent / success / warning / danger + 语义色 |
| `RCMSpacingTokens` | xxs(4) → xxxl(40) 8 级间距 |
| `RCMRadiusTokens` | sm(8) / md(12) / lg(16) / xl(24) 4 级圆角 |
| `RCMTypographyTokens` | hero / pageTitle / sectionTitle / body / caption / monoCaption 等 |
| `RCMControlSizeTokens` | buttonHeight / fieldHeight / rowMinHeight |
| `RCMStrokeTokens` | hairline |
| `RCMShadowTokens` | color / opacity / radius / x / y |
| `RCMHeroGradient` | startColor → endColor 渐变 |

额外提供了：
- **`Color(hex:)`** — 从 hex 字符串创建 Color（支持 `#RGB` / `#RRGGBB` / `#RRGGBBAA`）
- **`Color.toHex()`** — Color 转回 hex 字符串

### 2. RCMTheme.swift — 主题配置中心

```swift
// === 配置方式 ===

// ① 闭包配置（最灵活，适合运行时调整）
RCMTheme.shared.configure { $0.colors.primary = Color(hex: "#FF6B00") }

// ② JSON Data
let data = try Data(contentsOf: url)
try RCMTheme.shared.configure(jsonData: data)

// ③ JSON 文件 URL
try RCMTheme.shared.configure(jsonFileURL: url)

// ④ Bundle 内的 JSON 资源
try RCMTheme.shared.configure(jsonResource: "MyAppTheme")

// ⑤ 加载包内默认主题资源
try RCMTheme.shared.applyDefaultThemeFromPackage()

// ⑥ 应用内置预设
RCMTheme.shared.applyPreset(.orange)

// === 内置预设 ===
// .blue / .default       — 蓝色主题
// .orange / .rightClickMate — 橙色主题
// .purple / .videoHero      — 紫色主题

// === 导出当前 Token 为 JSON ===
let jsonString = try RCMTheme.shared.exportJSONString()

// === 便捷访问 ===
RCMTheme.shared.colors.primary        // Color
RCMTheme.shared.spacing.md            // CGFloat
RCMTheme.shared.radius.lg             // CGFloat
RCMTheme.shared.typography.body       // Font
RCMTheme.shared.controlSize.buttonHeight  // CGFloat
RCMTheme.shared.heroGradient.gradient     // LinearGradient
```

### 3. RCMText.swift — 文本组件

| 组件 | 用途 | 示例 |
|------|------|------|
| `RCMPageTitle(_:, subtitle:)` | 页面顶部大标题 + 可选副标题 | `RCMPageTitle("设置")` |
| `RCMSectionTitle(_:, subtitle:)` | 区块标题 | `RCMSectionTitle("通用")` |
| `RCMLabelText(_)` | 表单 label | `RCMLabelText("用户名")` |
| `RCMCaptionText(_)` | 辅助说明文字 | `RCMCaptionText("仅支持英文")` |
| `RCMMonoText(_)` | 等宽文本（路径/代码） | `RCMMonoText("/usr/local/bin")` |

### 4. RCMButtons.swift — 按钮与状态组件

#### 按钮样式

```swift
// 方式 A：用 RCMButton 组件
RCMButton(.primary, action: { handleSave() }) {
    Label("保存", systemImage: "checkmark")
}
RCMButton(.danger, action: { handleDelete() }) {
    Text("删除")
}

// 方式 B：给原生 Button 加修饰
Button("取消") {}
    .buttonStyle(RCMSoftButtonStyle())
```

| Role | 样式 | 适用场景 |
|------|------|---------|
| `.primary` | 实心填充主色 | 主要操作（保存、确认） |
| `.secondary` | 主色描边 | 次要操作（下一步） |
| `.soft` | 浅色背景 | 弱操作（取消、跳过） |
| `.danger` | 红色填充 | 危险操作（删除、重置） |

#### 其他组件

```swift
// 侧边栏图标（圆形背景 + SF Symbol）
RCMSidebarIcon(systemName: "house", tint: .blue, size: .medium)

// 徽章标签
RCMBadge("新功能", style: .success)
RCMBadge("v2.0")  // 默认风格

// 开关行
RCMToggle(isOn: $isEnabled, label: "自动更新")
```

### 5. RCMSurfaces.swift — 容器组件

#### 卡片与面板

```swift
// 基础卡片（灰色背景 + 圆角）
RCMCard {
    Text("卡片内容")
}

// 自定义背景色的卡片
RCMCard(background: Color.red.opacity(0.1)) {
    Text("红色调卡片")
}

// 分区卡片（标题 + 内容区域）
RCMPageSection("存储管理") {
    RCMValueRow("已用空间", value: "12.4 GB")
    RCMValueRow("剩余空间", value: "86.1 GB", tone: .green)
}

// Hero 面板（渐变背景，自动跟随主题）
RCMHeroPanel {
    VStack(alignment: .leading) {
        Text("欢迎使用").font(.title).foregroundColor(.white)
        Text("RightClickMate 让 Finder 更强大").foregroundColor(.white.opacity(0.8))
    }
}
```

#### 侧边栏

```swift
@State private var selection = "home"

let menuItems = [
    RCMSidebarMenuItem(id: "home", label: "首页", icon: "house", tint: .blue),
    RCMSidebarMenuItem(id: "settings", label: "设置", icon: "gearshape", tint: .gray),
]

RCMSidebarGroupView(title: nil, items: menuItems, selection: $selection)
```

#### 折叠面板 & 多行行

```swift
// 可展开/收起的区块
CollapsibleSection("高级选项") {
    Toggle("启用调试模式", isOn: $debugMode)
}

// 支持多行副标题的行（突破 lineLimit 限制）
MultilineSubtitleRow(
    systemIcon: "folder",
    iconColor: .blue,
    title: "项目目录",
    subtitle: "这是一个非常长的描述文字...\n可以换行显示"
) {
    Button("更改") {}
}
```

### 6. RCMRows.swift — 行组件

```swift
// 设置行（左标题 + 副标题 + 右侧自定义视图）
RCMSettingRow("文档目录", subtitle: "/Users/name/Documents") {
    RCMBadge("已授权", style: .success)
}

// 键值行（左 label + 右 value）
RCMValueRow("版本号", value: "2.1.0")
RCMValueRow("磁盘用量", value: "89%", tone: .orange)

// 带标签的内联字段
RCMInlineField("服务器地址") {
    TextField("https://...", text: $serverURL)
}
```

### 7. RCMDesignSystemPreview.swift — 可视化编辑器

一个完整的 **Design Token 预览 + 编辑 + 导出** 工具界面：

- 左侧：实时预览所有组件效果
- 右侧：滑块/颜色选择器调整 Token 值
- 底部：一键导出为 JSON

```swift
// 在你的 App 中预览或调试时直接使用
RCMDesignSystemPreview()
```

---

## 🔧 与 ThemeManager 的关系

这套 DesignSystem **不是**要替代你现有的 `ThemeManager.swift`，而是在它之上补了一层更稳定的视觉基础设施：

| 层级 | 职责 |
|------|------|
| **RCMDesignTokens + RCMTheme** | 定义和存储所有视觉参数（数据层） |
| **RCMText / Buttons / Surfaces / Rows** | 使用这些参数渲染的通用 UI 组件（展示层） |
| **ThemeManager** | 业务层面的主题切换逻辑（如深色/浅色模式、用户偏好） |

**建议迁移路径**：
1. 先在 PurchaseView、About 等简单页面替换按钮、标题、卡片
2. 再把 DirectorySettingsView、QuickAppsSettingsView 换成 `RCMPageSection + RCMSettingRow`
3. 最后考虑把 ThemeManager 里真正通用的组件逐步迁入 DesignSystem

---

## 平台要求

- **macOS 14+**（使用 `NSColor` / `AppKit`）
- **Swift 6 语言模式**（所有 Token 结构体实现 `Sendable`）
