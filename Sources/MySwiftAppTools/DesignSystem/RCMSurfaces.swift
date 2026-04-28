import SwiftUI

// MARK: - Sidebar Components

/*
 使用 RCMSidebarGroupView 需要准备的内容
 1. 导入 DesignSystem
 确保文件头部导入了 DesignSystem：
 import SwiftUI
 // 自动会导入 RCMSurfaces, RCMButtons, RCMDesignTokens

 2. 准备菜单项数据
 // 定义你的菜单项
 struct YourMenuItem: Hashable, Identifiable {
     public let id: String
     public let label: String
     public let icon: String
     public let tint: Color
 }

 3. 使用示例
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
 └── RCMTheme.shared (统一访问所有 Token)
 */

// MARK: - RCMSidebarMenuItem

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

// MARK: - RCMSidebarGroupView

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
        VStack(alignment: .leading, spacing: RCMTheme.shared.spacing.xs) {
            // 分组标题
            if let title {
                Text(title)
                    .font(RCMTheme.shared.typography.captionStrong)
                    .foregroundStyle(RCMTheme.shared.colors.textTertiary)
                    .padding(.leading, RCMTheme.shared.spacing.sm)
            }

            // 分组内的菜单项
            VStack(spacing: RCMTheme.shared.spacing.xxs) {
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

// MARK: - RCMSidebarItemButton

/// 单个侧边栏菜单项按钮
public struct RCMSidebarItemButton: View {
    let item: RCMSidebarMenuItem
    let isSelected: Bool
    let action: () -> Void

    public var body: some View {
        Button(action: action) {
            HStack(spacing: RCMTheme.shared.spacing.sm) {
                RCMSidebarIcon(
                    systemName: item.icon,
                    tint: item.tint,
                    size: .small
                )

                Text(item.label)
                    .font(RCMTheme.shared.typography.body15)

                Spacer()
            }
            .padding(.horizontal, RCMTheme.shared.spacing.sm)
            .padding(.vertical, RCMTheme.shared.spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: RCMTheme.shared.radius.sm, style: .continuous)
                    .fill(isSelected ? RCMTheme.shared.colors.accentSoft : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? RCMTheme.shared.colors.accent : RCMTheme.shared.colors.textPrimary)
    }
}

// MARK: - Surface Components

// MARK: RCMCard

public struct RCMCard<Content: View>: View {
    let padding: CGFloat
    let backgroundStyle: AnyShapeStyle
    let cornerRadius: CGFloat
    let content: Content

    /// Shared card surface. Omit `background` for the neutral default, or pass a
    /// branded color/gradient for hero cards without creating one-off surfaces.
    public init(
        padding: CGFloat = RCMTheme.shared.spacing.lg,
        background: some ShapeStyle = RCMTheme.shared.colors.cardGrayBackground,
        cornerRadius: CGFloat = RCMTheme.shared.radius.md,
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

// MARK: RCMPageSection

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
            VStack(alignment: .leading, spacing: RCMTheme.shared.spacing.xxs) {
                Text(title)
                    .font(RCMTheme.shared.typography.sectionTitle)
                    .foregroundStyle(RCMTheme.shared.colors.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(RCMTheme.shared.typography.caption)
                        .foregroundStyle(RCMTheme.shared.colors.textSecondary)
                }
            }
            .padding(.bottom, RCMTheme.shared.spacing.md)

            // 分隔线
            if let show = showsDivider, show {
                Divider()
                    .padding(.bottom, RCMTheme.shared.spacing.md)
            }

            // 内容区域 - 有浅灰色背景和圆角
            RCMCard {
                content
            }
        }
    }
}

// MARK: - RCMHeroPanel（使用 RCMTheme 的 heroGradient）

/// Hero 面板，根据 RCMTheme.shared.heroGradient 渲染渐变背景
public struct RCMHeroPanel<Content: View>: View {
    let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(RCMTheme.shared.spacing.xxl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RCMTheme.shared.heroGradient.gradient)
            .clipShape(RoundedRectangle(cornerRadius: RCMTheme.shared.radius.xl, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 18, x: 0, y: 10)
    }
}

// MARK: - RCMHeroPanelBlue（保留兼容，与 HeroPanel 等效）

@available(*, deprecated, message: "请使用 RCMHeroPanel")
public struct RCMHeroPanelBlue<Content: View>: View {
    let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        RCMHeroPanel(content: { self.content })
    }
}

// MARK: - RCMHeroPanelOrange（保留兼容）

@available(*, deprecated, message: "请使用 RCMHeroPanel")
public struct RCMHeroPanelOrange<Content: View>: View {
    let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(RCMTheme.shared.spacing.xxl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [
                        Color(hex: "#FF6B00"),
                        Color(hex: "#FF3D00"),
                        Color(hex: "#1F528C")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: RCMTheme.shared.radius.xl, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 18, x: 0, y: 10)
    }
}

// MARK: - MultilineSubtitleRow

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
                        .font(RCMTheme.shared.typography.body)
                        .foregroundStyle(.primary)
                }

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(RCMTheme.shared.typography.caption)
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

// MARK: - CollapsibleSection

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
                            .font(RCMTheme.shared.typography.sectionTitle)
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
        .clipShape(RoundedRectangle(cornerRadius: RCMTheme.shared.radius.md))
    }
}
