import SwiftUI

// MARK: - RCMDesignSystemGallery

/// DesignSystem 组件与页面模式 Gallery。
///
/// `RCMDesignSystemPreview` 主要用于调整 token；`RCMDesignSystemGallery` 用来观察
/// DesignSystem 在真实页面结构里的默认效果。
public struct RCMDesignSystemGallery: View {
    @State private var selection: GallerySection.ID = GallerySection.page.id
    @State private var isEnabled = true
    @State private var progress = 0.42

    public init() {}

    public var body: some View {
        HSplitView {
            sidebar
                .frame(minWidth: 220, idealWidth: 240, maxWidth: 280)

            selectedContent
                .frame(minWidth: 560)
        }
        .frame(minWidth: 900, minHeight: 640)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: RCMTheme.shared.spacing.lg) {
            RCMPageTitle("Gallery", subtitle: "DesignSystem 组件和页面模式")

            RCMSidebarGroupView(
                title: "页面",
                items: GallerySection.allCases.map(\.menuItem),
                selection: $selection
            )

            Spacer()
        }
        .padding(RCMTheme.shared.spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RCMTheme.shared.colors.cardBackground)
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch GallerySection(id: selection) {
        case .page:
            pageExample
        case .states:
            statesExample
        case .controls:
            controlsExample
        case .rows:
            rowsExample
        case .surfaces:
            surfacesExample
        }
    }

    private var pageExample: some View {
        RCMPage("标准设置页", subtitle: "推荐结构：RCMPage -> RCMPageSection -> RCMGroup -> Row / Control") {
            RCMPageSection("基础设置") {
                GalleryExample(
                    "RCMPageSection + RCMGroup + RCMSettingRow",
                    usage: "RCMPageSection { RCMGroup { RCMSettingRow(...) } }"
                ) {
                    RCMGroup("通用", subtitle: "常用偏好集中放在一个内容分组里。") {
                        RCMSettingRow("自动检查更新", subtitle: "启动后自动检查是否有新版本。") {
                            RCMToggle(isOn: $isEnabled, label: "启用")
                        }

                        RCMSettingRow("默认导出目录", subtitle: "/Users/name/Documents/Exports") {
                            RCMButton("更改", role: .soft, systemImage: "folder") {}
                        }
                    }
                }
            }

            RCMPageSection("状态反馈") {
                GalleryExample(
                    "RCMProgressPanel",
                    usage: "RCMProgressPanel(\"模型下载\", fractionCompleted: progress)"
                ) {
                    RCMProgressPanel(
                        "模型下载",
                        subtitle: "LaMa.mlpackage.zip",
                        fractionCompleted: progress,
                        statusText: "正在从最快的可用源下载...",
                        actionTitle: "取消",
                        actionSystemImage: "xmark"
                    ) {}
                }
            }

            RCMPageSection("操作") {
                GalleryExample(
                    "RCMButton",
                    usage: "RCMButton(\"保存设置\", role: .primary, systemImage: \"checkmark\")"
                ) {
                    RCMGroup(style: .plain) {
                        HStack(spacing: RCMTheme.shared.spacing.md) {
                            RCMButton("保存设置", role: .primary, systemImage: "checkmark") {}
                            RCMButton("恢复默认", role: .soft, systemImage: "arrow.counterclockwise") {}
                        }
                    }
                }
            }
        }
    }

    private var statesExample: some View {
        RCMPage("状态模式", subtitle: "空状态、错误状态、加载状态和进度面板是最常见的页面片段。") {
            RCMPageSection("空状态") {
                GalleryExample(
                    "RCMEmptyState",
                    usage: "RCMEmptyState(systemImage: \"tray\", title: \"暂无文件\")"
                ) {
                    RCMGroup {
                        RCMEmptyState(
                            systemImage: "tray",
                            title: "暂无文件",
                            message: "添加文件后会显示在这里。",
                            actionTitle: "添加文件",
                            actionSystemImage: "plus"
                        ) {}
                    }
                }
            }

            RCMPageSection("错误和加载") {
                HStack(alignment: .top, spacing: RCMTheme.shared.spacing.md) {
                    GalleryExample(
                        "RCMErrorState",
                        usage: "RCMErrorState(title: \"加载失败\", actionTitle: \"重试\")"
                    ) {
                        RCMGroup {
                            RCMErrorState(
                                title: "加载失败",
                                message: "请检查网络后重试。",
                                actionTitle: "重试"
                            ) {}
                        }
                    }

                    GalleryExample(
                        "RCMLoadingState",
                        usage: "RCMLoadingState(\"正在处理\", message: \"...\")"
                    ) {
                        RCMGroup {
                            RCMLoadingState("正在处理", message: "这通常只需要几秒。")
                        }
                    }
                }
            }
        }
    }

    private var controlsExample: some View {
        RCMPage("基础控件", subtitle: "按钮、徽章和开关默认跟随 RCMTheme。") {
            RCMPageSection("按钮") {
                GalleryExample(
                    "RCMButton",
                    usage: "RCMButton(\"主要操作\", role: .primary, systemImage: \"checkmark\")"
                ) {
                    RCMGroup {
                        HStack(spacing: RCMTheme.shared.spacing.md) {
                            RCMButton("主要操作", role: .primary, systemImage: "checkmark") {}
                            RCMButton("次要操作", role: .secondary, systemImage: "slider.horizontal.3") {}
                            RCMButton("轻量操作", role: .soft, systemImage: "sparkles") {}
                            RCMButton("危险操作", role: .danger, systemImage: "trash") {}
                        }
                    }
                }
            }

            RCMPageSection("徽章和开关") {
                GalleryExample(
                    "RCMBadge + RCMToggle",
                    usage: "RCMBadge(\"已完成\", style: .success) / RCMToggle(isOn: $value)"
                ) {
                    RCMGroup {
                        HStack(spacing: RCMTheme.shared.spacing.sm) {
                            RCMBadge("Pro", style: .accent)
                            RCMBadge("已完成", style: .success)
                            RCMBadge("待处理", style: .warning)
                            RCMBadge("失败", style: .danger)
                            RCMBadge(verbatim: "v1.0.0", style: .neutral)
                        }

                        RCMSettingRow("启用自动处理", subtitle: "适合二元开关型设置。") {
                            RCMToggle(isOn: $isEnabled, label: "启用")
                        }
                    }
                }
            }
        }
    }

    private var rowsExample: some View {
        RCMPage("行和标签", subtitle: "设置行、键值行、内联字段和流式标签。") {
            RCMPageSection("设置行") {
                GalleryExample(
                    "RCMSettingRow + RCMValueRow",
                    usage: "RCMSettingRow(\"标题\") { trailing } / RCMValueRow(\"标题\", value: \"值\")"
                ) {
                    RCMGroup {
                        RCMSettingRow("图片输出格式", subtitle: "用于批量处理后的默认格式。") {
                            RCMBadge("PNG", style: .accent)
                        }

                        RCMValueRow("今日处理", value: "128 张", tone: RCMTheme.shared.colors.success)
                        RCMValueRow("缓存占用", value: "240 MB", tone: RCMTheme.shared.colors.warning)
                    }
                }
            }

            RCMPageSection("流式标签") {
                GalleryExample(
                    "RCMPillFlow",
                    usage: "RCMPillFlow(items, sortOrder: .ascending, showsRemoveButton: true)"
                ) {
                    RCMGroup {
                        RCMPillFlow(
                            ["75%", "100%", "110%", "1280x720", "1920x1080", "2560x1600", "4K"],
                            sortOrder: .ascending,
                            minItemWidth: 88,
                            showsRemoveButton: true,
                            onTap: { _ in },
                            onRemove: { _ in }
                        )
                    }
                }
            }
        }
    }

    private var surfacesExample: some View {
        RCMPage("容器分层", subtitle: "PageSection 管章节，Group 管内容分组，Card 是底层视觉容器。") {
            RCMPageSection("分组") {
                GalleryExample(
                    "RCMGroup",
                    usage: "RCMGroup(\"默认分组\", subtitle: \"...\") { content }"
                ) {
                    RCMGroup("默认分组", subtitle: "默认浅背景，无边框。") {
                        RCMValueRow("语义", value: "内容分组")
                        RCMValueRow("默认背景", value: "浅色")
                    }
                }
            }

            RCMPageSection("强调面板") {
                GalleryExample(
                    "RCMHeroPanel",
                    usage: "RCMHeroPanel { content }"
                ) {
                    RCMHeroPanel {
                        VStack(alignment: .leading, spacing: RCMTheme.shared.spacing.sm) {
                            Text("Hero Panel")
                                .font(RCMTheme.shared.typography.hero)
                                .foregroundStyle(.white)
                            Text("用于第一屏强调、关键状态或付费权益说明。")
                                .font(RCMTheme.shared.typography.body)
                                .foregroundStyle(.white.opacity(0.82))
                        }
                    }
                }
            }

            RCMPageSection("底层卡片") {
                GalleryExample(
                    "RCMCard",
                    usage: "RCMCard { ... } / RCMCard(background: ...) { ... }"
                ) {
                    HStack(alignment: .top, spacing: RCMTheme.shared.spacing.md) {
                        RCMCard {
                            Text("默认 RCMCard 只提供 padding，不绘制背景。")
                                .font(RCMTheme.shared.typography.body)
                        }

                        RCMCard(background: RCMTheme.shared.colors.accentSoft) {
                            Text("显式传入 background 时才绘制背景和圆角。")
                                .font(RCMTheme.shared.typography.body)
                        }
                    }
                }
            }
        }
    }
}

private struct GalleryExample<Content: View>: View {
    let title: LocalizedStringKey
    let usage: String
    let content: Content

    init(
        _ title: LocalizedStringKey,
        usage: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.usage = usage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RCMTheme.shared.spacing.sm) {
            VStack(alignment: .leading, spacing: RCMTheme.shared.spacing.xs) {
                Text(title)
                    .font(RCMTheme.shared.typography.bodyStrong)
                    .foregroundStyle(RCMTheme.shared.colors.primary)

                Text(verbatim: usage)
                    .font(RCMTheme.shared.typography.monoCaption)
                    .foregroundStyle(RCMTheme.shared.colors.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, RCMTheme.shared.spacing.sm)
                    .padding(.vertical, RCMTheme.shared.spacing.xs)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: RCMTheme.shared.radius.sm, style: .continuous)
                            .fill(RCMTheme.shared.colors.subtleFill)
                    )
            }

            content
        }
    }
}

private enum GallerySection: String, CaseIterable, Identifiable {
    case page
    case states
    case controls
    case rows
    case surfaces

    var id: String { rawValue }

    init(id: String) {
        self = GallerySection(rawValue: id) ?? .page
    }

    var menuItem: RCMSidebarMenuItem {
        RCMSidebarMenuItem(
            id: id,
            label: label,
            icon: icon,
            tint: tint
        )
    }

    private var label: String {
        switch self {
        case .page: return "标准页面"
        case .states: return "状态模式"
        case .controls: return "基础控件"
        case .rows: return "行与标签"
        case .surfaces: return "容器分层"
        }
    }

    private var icon: String {
        switch self {
        case .page: return "rectangle.3.group"
        case .states: return "circle.dotted"
        case .controls: return "switch.2"
        case .rows: return "list.bullet.rectangle"
        case .surfaces: return "square.stack.3d.up"
        }
    }

    private var tint: Color {
        switch self {
        case .page: return RCMTheme.shared.colors.primary
        case .states: return RCMTheme.shared.colors.warning
        case .controls: return RCMTheme.shared.colors.success
        case .rows: return .purple
        case .surfaces: return .teal
        }
    }
}

#Preview{
    RCMDesignSystemGallery()
}
