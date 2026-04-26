import SwiftUI

// MARK: - Sidebar Components
/*
使用 RCMSidebarGroupView 需要准备的内容
1. 导入 DesignSystem
确保文件头部导入了 DesignSystem：

swift
复制
import SwiftUI
// 自动会导入 RCMSurfaces, RCMButtons, RCMDesignTokens
2. 准备菜单项数据
swift
复制
// 定义你的菜单项
struct YourMenuItem: Hashable, Identifiable {
    public let id: String
    public let label: String
    public let icon: String
    public let tint: Color
}
3. 使用示例
swift
复制
struct ExampleView: View {
    @State private var selection: String = "home"
    
    // 定义分组
    let mainGroup = [
        RCMSidebarMenuItem(id: "home", label: "首页", icon: "house", tint: .blue),
        RCMSidebarMenuItem(id: "settings", label: "设置", icon: "gearshape", tint: .gray),
    ]
    
    let adminGroup = [
        RCMSidebarMenuItem(id: "users", label: "用户", icon: "person.2", tint: .green),
    ]
    
    public var body: some View {
        VStack {
            // 分组1：不需要标题
            RCMSidebarGroupView(
                title: nil,
                items: mainGroup,
                selection: $selection
            )
            
            // 分组2：需要标题
            RCMSidebarGroupView(
                title: "管理",
                items: adminGroup,
                selection: $selection
            )
        }
    }
}
4. 组件依赖关系
RCMSidebarGroupView
├── RCMSidebarMenuItem (数据)
└── RCMSidebarItemButton
    └── RCMSidebarIcon (来自 RCMButtons.swift)
        └── RCMSidebarIcon.PresetTint (预设颜色)

样式依赖:
├── RCMColor (RCMDesignTokens.swift)
├── RCMSpacing (RCMDesignTokens.swift)
├── RCMRadius (RCMDesignTokens.swift)
└── RCMTypography (RCMDesignTokens.swift)
5. 预设图标颜色
swift
复制
RCMSidebarIcon.PresetTint.gray    // 灰色
RCMSidebarIcon.PresetTint.blue    // 蓝色
RCMSidebarIcon.PresetTint.green   // 绿色
RCMSidebarIcon.PresetTint.orange  // 橙色
RCMSidebarIcon.PresetTint.red     // 红色
RCMSidebarIcon.PresetTint.purple  // 紫色
RCMSidebarIcon.PresetTint.pink    // 粉色
RCMSidebarIcon.PresetTint.teal    // 青色
RCMSidebarIcon.PresetTint.indigo  // 靛蓝
总结：使用前只需要确保 DesignSystem 文件都在项目里，然后准备好菜单数据就行。
 */
/// 侧边栏菜单项数据
public struct RCMSidebarMenuItem: Hashable, Identifiable {
    public let id: String
    public let label: String
    public let icon: String
    public let tint: Color
    
    public init(id: String = UUID().uuidString, label: String, icon: String, tint: Color) {
        self.id = id
        self.label = label
        self.icon = icon
        self.tint = tint
    }
}

/// 侧边栏分组视图
public struct RCMSidebarGroupView: View {
    let title: String?
    let items: [RCMSidebarMenuItem]
    @Binding var selection: String
    
    public init(title: String? = nil, items: [RCMSidebarMenuItem], selection: Binding<String>) {
        self.title = title
        self.items = items
        self._selection = selection
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: RCMSpacing.xs) {
            // 分组标题
            if let title {
                Text(title)
                    .font(RCMTypography.captionStrong)
                    .foregroundStyle(RCMColor.textTertiary)
                    .padding(.leading, RCMSpacing.sm)
            }
            
            // 分组内的菜单项
            VStack(spacing: RCMSpacing.xxs) {
                ForEach(items) { item in
                    RCMSidebarItemButton(
                        item: item,
                        isSelected: selection == item.id
                    ) {
                        selection = item.id
                    }
                }
            }
        }
    }
}

/// 单个侧边栏菜单项按钮
public struct RCMSidebarItemButton: View {
    let item: RCMSidebarMenuItem
    let isSelected: Bool
    let action: () -> Void
    
    public var body: some View {
        Button(action: action) {
            HStack(spacing: RCMSpacing.sm) {
                RCMSidebarIcon(
                    systemName: item.icon,
                    tint: item.tint,
                    size: .small
                )
                
                Text(item.label)
                    .font(RCMTypography.body15)
                
                Spacer()
            }
            .padding(.horizontal, RCMSpacing.sm)
            .padding(.vertical, RCMSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: RCMRadius.sm, style: .continuous)
                    .fill(isSelected ? RCMColor.accentSoft : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? RCMColor.accent : RCMColor.textPrimary)
    }
}

// MARK: - Surface Components

public struct RCMCard<Content: View>: View {
    let padding: CGFloat
    // Type erasure lets the shared card accept both solid colors and gradients.
    let backgroundStyle: AnyShapeStyle
    let cornerRadius: CGFloat
    let content: Content

    /// Shared card surface. Omit `background` for the neutral default, or pass a
    /// branded color/gradient for hero cards without creating one-off surfaces.
    public init(
        padding: CGFloat = RCMSpacing.lg,
        background: some ShapeStyle = RCMColor.cardGrayBackground,
        cornerRadius: CGFloat = RCMRadius.md,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.backgroundStyle = AnyShapeStyle(background)
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(backgroundStyle)
            )
    }
}

public struct RCMPageSection<Content: View>: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey?
    let showsDivider: Bool?
    let content: Content

    public init(
        _ title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        showsDivider: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.showsDivider = showsDivider
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题区域 - 无背景，直接显示在页面上
            VStack(alignment: .leading, spacing: RCMSpacing.xxs) {
                Text(title)
                    .font(RCMTypography.sectionTitle)
                    .foregroundStyle(RCMColor.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(RCMTypography.caption)
                        .foregroundStyle(RCMColor.textSecondary)
                }
            }
            .padding(.bottom, RCMSpacing.md)

            // 分隔线
            if let show = showsDivider, show {
                Divider()
                    .padding(.bottom, RCMSpacing.md)
            }

            // 内容区域 - 有浅灰色背景和圆角
            RCMCard {
                content
            }
        }
    }
}

public struct RCMHeroPanel<Content: View>: View {
    let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(RCMSpacing.xxl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.57, blue: 0.25),
                        Color(red: 1.0, green: 0.32, blue: 0.35),
                        Color(red: 0.12, green: 0.32, blue: 0.36)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: RCMRadius.xl, style: .continuous))
            .shadow(color: RCMShadow.card, radius: 18, x: 0, y: 10)
    }
}

// MARK: - 自定义行组件（支持多行 Subtitle）

/// 多行 Subtitle 行组件（避免 SKBaseRow 的 lineLimit 限制）
public struct MultilineSubtitleRow<Content: View>: View {
    var systemIcon: String? = nil
    var iconImage: NSImage? = nil
    var iconColor: Color? = nil
    let title: String?
    let subtitle: String?
    let content: Content
    
    /// 用 @ViewBuilder 让 content 参数支持多视图
    public init(systemIcon: String? = nil,
         iconImage: NSImage? = nil,
         iconColor: Color? = nil,
         title: String? = nil,
         subtitle: String? = nil,
         @ViewBuilder content: () -> Content) {
        self.systemIcon = systemIcon
        self.iconImage = iconImage
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            iconView
            
            VStack(alignment: .leading, spacing: 2) {
                if let title = title {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(.primary)
                }
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(nil)  // 允许多行，不限制
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            Spacer()
            
            content
        }
        .padding(.vertical, 6)
    }
    
    @ViewBuilder
    private var iconView: some View {
        if let iconImage = iconImage {
            Image(nsImage: iconImage)
                .resizable()
                .frame(width: 28, height: 28)
        } else if let systemIcon = systemIcon, let iconColor = iconColor {
            Image(systemName: systemIcon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(iconColor)
                )
        }
    }
}

/*
 struct SettingsView: View {
     var body: some View {
         VStack(spacing: 16) {
             // 权限设置...
             
             // 折叠的帮助区域
             CollapsibleSection("需要帮助?") {
                 Button(action: {}) {
                     Label("查看常见问题", systemImage: "questionmark.circle")
                 }
                 .buttonStyle(.plain)
                 
                 Button(action: {}) {
                     Label("联系支持", systemImage: "envelope")
                 }
                 .buttonStyle(.plain)
                 
                 Button(action: {}) {
                     Label("发送反馈", systemImage: "bubble.left")
                 }
                 .buttonStyle(.plain)
             }
         }
         .padding()
     }
 }

 */

public struct CollapsibleSection<Content: View>: View {
    var title: String? = nil
    @State private var isExpanded = false
    @ViewBuilder let content: () -> Content
    
    public init(_ title: String?, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header - 可点击
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    if let title = title {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Content
            if isExpanded {
                if title != nil {
                    Divider()
                        .padding(.horizontal)
                }
                VStack(alignment: .leading, spacing: 12) {
                    content()
                }
                .padding()
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
