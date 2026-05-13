import SwiftUI

// MARK: - Page Layout Patterns

/// 标准页面骨架。
///
/// 推荐结构：
/// ```swift
/// RCMPage("设置", subtitle: "管理应用偏好") {
///     RCMPageSection("通用") {
///         RCMGroup {
///             RCMSettingRow("自动更新") {
///                 RCMToggle(isOn: $isEnabled, label: "启用")
///             }
///         }
///     }
/// }
/// ```
public struct RCMPage<Content: View>: View {
    let title: LocalizedStringKey?
    let subtitle: LocalizedStringKey?
    let maxWidth: CGFloat?
    let padding: CGFloat
    let spacing: CGFloat
    let showsBackground: Bool
    let scrolls: Bool
    let content: Content

    public init(
        _ title: LocalizedStringKey? = nil,
        subtitle: LocalizedStringKey? = nil,
        maxWidth: CGFloat? = 880,
        padding: CGFloat = RCMTheme.shared.spacing.xxl,
        spacing: CGFloat = RCMTheme.shared.spacing.xl,
        showsBackground: Bool = false,
        scrolls: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.maxWidth = maxWidth
        self.padding = padding
        self.spacing = spacing
        self.showsBackground = showsBackground
        self.scrolls = scrolls
        self.content = content()
    }

    public var body: some View {
        Group {
            if scrolls {
                ScrollView {
                    pageContent
                }
            } else {
                pageContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(showsBackground ? RCMTheme.shared.colors.pageBackground : Color.clear)
    }

    private var pageContent: some View {
        RCMPageStack(
            title: title,
            subtitle: subtitle,
            maxWidth: maxWidth,
            padding: padding,
            spacing: spacing
        ) {
            content
        }
    }
}

/// 页面内容栈。
///
/// 当页面外部已经提供 `ScrollView`、`NavigationSplitView` 或自定义容器时，用它复用
/// DesignSystem 的页面标题、最大宽度、padding 和 section 间距规则。
public struct RCMPageStack<Content: View>: View {
    let title: LocalizedStringKey?
    let subtitle: LocalizedStringKey?
    let maxWidth: CGFloat?
    let padding: CGFloat
    let spacing: CGFloat
    let content: Content

    public init(
        title: LocalizedStringKey? = nil,
        subtitle: LocalizedStringKey? = nil,
        maxWidth: CGFloat? = 880,
        padding: CGFloat = RCMTheme.shared.spacing.xxl,
        spacing: CGFloat = RCMTheme.shared.spacing.xl,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.maxWidth = maxWidth
        self.padding = padding
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            if let title {
                RCMPageTitle(title, subtitle: subtitle)
            }

            content
        }
        .frame(maxWidth: maxWidth, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(padding)
    }
}
