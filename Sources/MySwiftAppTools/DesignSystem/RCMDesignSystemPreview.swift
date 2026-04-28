import SwiftUI
import UniformTypeIdentifiers
#if canImport(AppKit)
import AppKit
#endif


// MARK: - RCMSystemColorWell：封装 NSColorWell，弹出系统颜色面板

/// 点击颜色块时打开 macOS 系统 NSColorPanel，选择后自动回调
@MainActor
private struct RCMSystemColorWell: NSViewRepresentable {
    @Binding var color: Color

    func makeNSView(context: Context) -> NSColorWell {
        let well = NSColorWell(frame: .init(x: 0, y: 0, width: 28, height: 24))
        well.color = NSColor(color)
        well.isBordered = true
        well.action = #selector(Coordinator.colorChanged(_:))
        well.target = context.coordinator
        return well
    }

    func updateNSView(_ nsView: NSColorWell, context: Context) {
        // 外部 Color 变化时同步到 NSColorWell（避免循环）
        if nsView.color != NSColor(color) {
            nsView.color = NSColor(color)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    @MainActor
    class Coordinator: NSObject {
        var parent: RCMSystemColorWell
        init(_ parent: RCMSystemColorWell) { self.parent = parent }

        @objc func colorChanged(_ sender: NSColorWell) {
            // 用户在系统面板中选择了新颜色（已在 MainActor 上）
            parent.color = Color(sender.color)
        }
    }
}


// MARK: - NSColor 扩展：转 hex

extension NSColor {
    /// 将 NSColor 转为 "#RRGGBB" 格式（忽略 alpha）
    func toHexRGB() -> String {
        guard let cgColor = usingColorSpace(.sRGB)?.cgColor else { return "#000000" }
        let components = cgColor.components ?? [0, 0, 0]
        let r = Int((components[0] * 255).rounded())
        let g = Int((components[1] * 255).rounded())
        let b = Int((components[2] * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - RCMDesignSystemPreview

/// Design System 可视化编辑器
///
/// 功能：
/// - 左侧实时预览所有组件效果
/// - 右侧调整颜色、间距、圆角、字体等参数
/// - 导出当前配置为 JSON 文件，供 `RCMTheme.shared.configure(jsonResource:)` 使用
///
public struct RCMDesignSystemPreview: View {
    @State private var draftColors: RCMColorTokens = RCMTheme.shared.colors
    @State private var draftSpacing: RCMSpacingTokens = RCMTheme.shared.spacing
    @State private var draftRadius: RCMRadiusTokens = RCMTheme.shared.radius
    @State private var draftTypography: RCMTypographyTokens = RCMTheme.shared.typography
    @State private var draftControlSize: RCMControlSizeTokens = RCMTheme.shared.controlSize
    @State private var draftHeroGradient: RCMHeroGradient = RCMTheme.shared.heroGradient

    @State private var selectedPreset: RCMPresetTheme? = nil
    @State private var showSavePanel = false
    @State private var exportError: String? = nil
    @State private var showExportError = false

    @State private var previewSelection: String = "home"

    public init() {}

    public var body: some View {
        HSplitView {
            // ── 左侧：实时预览区 ──────────────────────────────
            previewPanel
                .frame(minWidth: 400)

            // ── 右侧：参数调整区 ──────────────────────────────
            editorPanel
                .frame(minWidth: 320)
        }
        .frame(minWidth: 800, minHeight: 600)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                presetPicker
                Button("重置") { resetToTheme() }
                Button("应用到 Runtime") { applyToTheme() }
                Button("导出 JSON") { exportJSON() }
            }
        }
        .fileExporter(
            isPresented: $showSavePanel,
            document: RCMThemeJSONDocument(tokens: buildDraftTokens()),
            contentType: .json,
            defaultFilename: "MyAppTheme"
        ) { result in
            switch result {
            case .success(let url):
                break
            case .failure(let error):
                exportError = error.localizedDescription
                showExportError = true
            }
        }
        .alert("导出失败", isPresented: $showExportError) {
            Button("确定") {}
        } message: {
            Text(exportError ?? "未知错误")
        }
    }

    // MARK: - 构建 Draft Tokens

    private func buildDraftTokens() -> RCMDesignTokens {
        var t = RCMDesignTokens()
        t.colors = draftColors
        t.spacing = draftSpacing
        t.radius = draftRadius
        t.typography = draftTypography
        t.controlSize = draftControlSize
        t.heroGradient = draftHeroGradient
        return t
    }

    // MARK: - 预设切换

    private var presetPicker: some View {
        Picker("预设", selection: $selectedPreset) {
            Text("（当前）").tag(nil as RCMPresetTheme?)
            ForEach(RCMPresetTheme.allPresets) { preset in
                Text(preset.name).tag(preset as RCMPresetTheme?)
            }
        }
        .onChange(of: selectedPreset) { oldValue, newValue in
            guard let preset = newValue else { return }
            loadTokens(preset.tokens)
        }
    }

    // MARK: - 预览区

    private var previewPanel: some View {
        ScrollView {
            VStack(spacing: RCMTheme.shared.spacing.xl) {
                // 颜色预览
                previewSection("颜色") {
                    VStack(alignment: .leading, spacing: 8) {
                        colorSwatchRow("Primary", color: draftColors.primary)
                        colorSwatchRow("Accent", color: draftColors.accent)
                        colorSwatchRow("Success", color: draftColors.success)
                        colorSwatchRow("Warning", color: draftColors.warning)
                        colorSwatchRow("Danger", color: draftColors.danger)
                    }
                }

                // 按钮预览
                previewSection("按钮") {
                    VStack(spacing: draftSpacing.md) {
                        HStack(spacing: draftSpacing.md) {
                            previewPrimaryButton()
                            previewSecondaryButton()
                            previewSoftButton()
                            previewDangerButton()
                        }
                        HStack(spacing: draftSpacing.md) {
                            previewAccentBadge()
                            previewSuccessBadge()
                            previewWarningBadge()
                            previewDangerBadge()
                        }
                    }
                }

                // 文字层级预览
                previewSection("文字层级") {
                    VStack(alignment: .leading, spacing: draftSpacing.xs) {
                        Text("页面大标题 Hero")
                            .font(previewFont(draftTypography.heroSize, weight: draftTypography.heroWeight))
                            .foregroundStyle(draftColors.primary)
                        Text("章节标题 Section")
                            .font(previewFont(draftTypography.sectionTitleSize, weight: draftTypography.sectionTitleWeight))
                            .foregroundStyle(draftColors.primary)
                        Text("正文内容 Body")
                            .font(previewFont(draftTypography.bodySize, weight: draftTypography.bodyWeight))
                            .foregroundStyle(.primary)
                        Text("说明文字 Caption")
                            .font(previewFont(draftTypography.captionSize, weight: draftTypography.captionWeight))
                            .foregroundStyle(.secondary)
                    }
                }

                // 侧边栏预览
                previewSection("侧边栏") {
                    HStack(spacing: 0) {
                        sidebarPreview()
                        Spacer()
                    }
                }

                // 卡片预览
                previewSection("卡片 & 控件尺寸") {
                    VStack(spacing: draftSpacing.md) {
                        // Hero 面板
                        heroPanelPreview()
                        // 普通卡片
                        cardPreview()
                        // 设置行
                        settingRowPreview()
                    }
                }

                // 圆角预览
                previewSection("圆角") {
                    HStack(spacing: draftSpacing.md) {
                        roundedRectPreview(label: "sm", radius: draftRadius.sm)
                        roundedRectPreview(label: "md", radius: draftRadius.md)
                        roundedRectPreview(label: "lg", radius: draftRadius.lg)
                        roundedRectPreview(label: "xl", radius: draftRadius.xl)
                    }
                }
            }
            .padding(RCMTheme.shared.spacing.lg)
        }
        .background(Color(.textBackgroundColor))
    }

    private func previewSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: draftSpacing.sm) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
        }
    }

    // MARK: - 编辑区

    private var editorPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                colorEditor
                spacingEditor
                radiusEditor
                typographyEditor
                controlSizeEditor
            }
            .padding(RCMTheme.shared.spacing.md)
        }
        .background(Color(.controlBackgroundColor))
    }

    // MARK: - 颜色编辑器

    private var colorEditor: some View {
        editorSection("颜色") {
            colorRow("Primary", color: $draftColors.primary)
            colorRow("Accent", color: $draftColors.accent)
            colorRow("Success", color: $draftColors.success)
            colorRow("Warning", color: $draftColors.warning)
            colorRow("Danger", color: $draftColors.danger)
            colorRow("Hero Start", color: $draftHeroGradient.startColor)
            colorRow("Hero End", color: $draftHeroGradient.endColor)
        }
    }

    // MARK: - 间距编辑器

    private var spacingEditor: some View {
        editorSection("间距") {
            spacingRow("xxs", value: $draftSpacing.xxs)
            spacingRow("xs", value: $draftSpacing.xs)
            spacingRow("sm", value: $draftSpacing.sm)
            spacingRow("md", value: $draftSpacing.md)
            spacingRow("lg", value: $draftSpacing.lg)
            spacingRow("xl", value: $draftSpacing.xl)
            spacingRow("xxl", value: $draftSpacing.xxl)
            spacingRow("xxxl", value: $draftSpacing.xxxl)
        }
    }

    // MARK: - 圆角编辑器

    private var radiusEditor: some View {
        editorSection("圆角") {
            spacingRow("sm", value: $draftRadius.sm, range: 0...40)
            spacingRow("md", value: $draftRadius.md, range: 0...40)
            spacingRow("lg", value: $draftRadius.lg, range: 0...40)
            spacingRow("xl", value: $draftRadius.xl, range: 0...40)
        }
    }

    // MARK: - 字体编辑器

    private var typographyEditor: some View {
        editorSection("字体大小") {
            sizeRow("Hero", value: $draftTypography.heroSize, range: 16...60)
            sizeRow("PageTitle", value: $draftTypography.pageTitleSize, range: 10...40)
            sizeRow("SectionTitle", value: $draftTypography.sectionTitleSize, range: 10...36)
            sizeRow("Body15", value: $draftTypography.body15Size, range: 10...32)
            sizeRow("Body", value: $draftTypography.bodySize, range: 10...28)
            sizeRow("Caption", value: $draftTypography.captionSize, range: 8...24)
        }
    }

    // MARK: - 控件尺寸编辑器

    private var controlSizeEditor: some View {
        editorSection("控件尺寸") {
            sizeRow("Button Height", value: $draftControlSize.buttonHeight, range: 24...60)
            sizeRow("Field Height", value: $draftControlSize.fieldHeight, range: 24...60)
            sizeRow("Row MinHeight", value: $draftControlSize.rowMinHeight, range: 36...80)
        }
    }

    // MARK: - 辅助视图

    private func editorSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            VStack(spacing: 8) {
                content()
            }
            .padding(.top, 8)
            Divider()
                .padding(.top, 12)
        }
    }

    private func colorRow(_ label: String, color: Binding<Color>) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .frame(width: 80, alignment: .leading)

            // 点击弹出 macOS 系统颜色选择器（NSColorPanel）
            RCMSystemColorWell(color: color)
                .frame(width: 28, height: 24)
                .help("点击选择颜色")

            // hex 文本框（只读显示，方便复制）
            Text(color.wrappedValue.toHex())
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func spacingRow(_ label: String, value: Binding<CGFloat>, range: ClosedRange<CGFloat> = 0...80) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .frame(width: 50, alignment: .leading)

            Slider(value: value, in: range, step: 1)
                .frame(maxWidth: .infinity)

            Text("\(Int(value.wrappedValue))")
                .font(.system(.caption, design: .monospaced))
                .frame(width: 28, alignment: .trailing)
        }
    }

    private func sizeRow(_ label: String, value: Binding<CGFloat>, range: ClosedRange<CGFloat>) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .frame(width: 80, alignment: .leading)

            Stepper(
                value: value,
                in: range,
                step: 1
            ) {
                Text("\(Int(value.wrappedValue))")
                    .font(.system(.caption, design: .monospaced))
                    .frame(width: 28, alignment: .trailing)
            }
        }
    }

    // MARK: - 预览辅助视图

    private func colorSwatchRow(_ label: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 20, height: 20)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(color.toHex())
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private func previewFont(_ size: CGFloat, weight: String) -> Font {
        let w: Font.Weight
        switch weight {
        case "bold": w = .bold
        case "semibold": w = .semibold
        case "medium": w = .medium
        case "regular": w = .regular
        default: w = .regular
        }
        return .system(size: size, weight: w, design: .rounded)
    }

    private func roundedRectPreview(label: String, radius: CGFloat) -> some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: radius)
                .fill(draftColors.primary)
                .frame(width: 48, height: 48)
            Text("\(Int(radius))")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }

    private func previewPrimaryButton() -> some View {
        Button("主要") {}
            .font(.system(size: draftTypography.bodyStrongSize, weight: .semibold))
            .foregroundColor(.white)
            .frame(height: draftControlSize.buttonHeight)
            .padding(.horizontal, draftSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: draftRadius.md)
                    .fill(draftColors.primary)
            )
    }

    private func previewSecondaryButton() -> some View {
        Button("次要") {}
            .font(.system(size: draftTypography.bodyStrongSize, weight: .semibold))
            .foregroundColor(draftColors.primary)
            .frame(height: draftControlSize.buttonHeight)
            .padding(.horizontal, draftSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: draftRadius.md)
                    .stroke(draftColors.primary, lineWidth: 1.5)
            )
    }

    private func previewSoftButton() -> some View {
        Button("柔和") {}
            .font(.system(size: draftTypography.bodyStrongSize, weight: .semibold))
            .foregroundColor(draftColors.primary)
            .frame(height: draftControlSize.buttonHeight)
            .padding(.horizontal, draftSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: draftRadius.md)
                    .fill(draftColors.accent.opacity(0.12))
            )
    }

    private func previewDangerButton() -> some View {
        Button("危险") {}
            .font(.system(size: draftTypography.bodyStrongSize, weight: .semibold))
            .foregroundColor(.white)
            .frame(height: draftControlSize.buttonHeight)
            .padding(.horizontal, draftSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: draftRadius.md)
                    .fill(draftColors.danger)
            )
    }

    private func previewAccentBadge() -> some View {
        Text("Pro")
            .font(.system(size: draftTypography.captionStrongSize, weight: .semibold))
            .foregroundColor(draftColors.primary)
            .padding(.horizontal, draftSpacing.xs)
            .padding(.vertical, draftSpacing.xxs)
            .background(Capsule().fill(draftColors.primary.opacity(0.12)))
    }

    private func previewSuccessBadge() -> some View {
        Text("成功")
            .font(.system(size: draftTypography.captionStrongSize, weight: .semibold))
            .foregroundColor(draftColors.success)
            .padding(.horizontal, draftSpacing.xs)
            .padding(.vertical, draftSpacing.xxs)
            .background(Capsule().fill(draftColors.success.opacity(0.12)))
    }

    private func previewWarningBadge() -> some View {
        Text("警告")
            .font(.system(size: draftTypography.captionStrongSize, weight: .semibold))
            .foregroundColor(draftColors.warning)
            .padding(.horizontal, draftSpacing.xs)
            .padding(.vertical, draftSpacing.xxs)
            .background(Capsule().fill(draftColors.warning.opacity(0.12)))
    }

    private func previewDangerBadge() -> some View {
        Text("危险")
            .font(.system(size: draftTypography.captionStrongSize, weight: .semibold))
            .foregroundColor(draftColors.danger)
            .padding(.horizontal, draftSpacing.xs)
            .padding(.vertical, draftSpacing.xxs)
            .background(Capsule().fill(draftColors.danger.opacity(0.12)))
    }

    private func sidebarPreview() -> some View {
        VStack(alignment: .leading, spacing: draftSpacing.xxs) {
            sidebarItem(icon: "house", label: "首页", isSelected: previewSelection == "home")
                .onTapGesture { previewSelection = "home" }
            sidebarItem(icon: "gearshape", label: "设置", isSelected: previewSelection == "settings")
                .onTapGesture { previewSelection = "settings" }
        }
        .padding(draftSpacing.sm)
        .background(Color(.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: draftRadius.md))
        .frame(width: 160)
    }

    private func sidebarItem(icon: String, label: String, isSelected: Bool) -> some View {
        HStack(spacing: draftSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isSelected ? draftColors.accent : .secondary)
                .frame(width: 20)

            Text(label)
                .font(.system(size: draftTypography.body15Size))
                .foregroundStyle(isSelected ? draftColors.accent : .primary)

            Spacer()
        }
        .padding(.horizontal, draftSpacing.sm)
        .padding(.vertical, draftSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: draftRadius.sm)
                .fill(isSelected ? draftColors.accent.opacity(0.12) : Color.clear)
        )
    }

    private func heroPanelPreview() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Hero 面板")
                .font(.system(size: draftTypography.pageTitleSize, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("使用 HeroGradient 的渐变背景")
                .font(.system(size: draftTypography.bodySize))
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(draftSpacing.xxl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [draftHeroGradient.startColor, draftHeroGradient.endColor],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: draftRadius.xl))
    }

    private func cardPreview() -> some View {
        VStack(alignment: .leading, spacing: draftSpacing.xs) {
            Text("卡片标题")
                .font(.system(size: draftTypography.sectionTitleSize, weight: .semibold))
                .foregroundStyle(.primary)
            Text("卡片内容，浅灰色背景，带圆角")
                .font(.system(size: draftTypography.bodySize))
                .foregroundStyle(.secondary)
        }
        .padding(draftSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: draftRadius.md)
                .fill(Color(.secondarySystemFill))
        )
    }

    private func settingRowPreview() -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("设置项标题")
                    .font(.system(size: draftTypography.bodyStrongSize, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("设置项说明文字")
                    .font(.system(size: draftTypography.captionSize))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("值")
                .font(.system(size: draftTypography.bodyStrongSize, weight: .semibold))
                .foregroundStyle(draftColors.primary)
        }
        .padding(.vertical, draftSpacing.sm)
        .frame(minHeight: draftControlSize.rowMinHeight)
    }

    // MARK: - 操作方法

    private func resetToTheme() {
        loadTokens(RCMTheme.shared.tokens)
        selectedPreset = nil
    }

    private func loadTokens(_ tokens: RCMDesignTokens) {
        draftColors = tokens.colors
        draftSpacing = tokens.spacing
        draftRadius = tokens.radius
        draftTypography = tokens.typography
        draftControlSize = tokens.controlSize
        draftHeroGradient = tokens.heroGradient
    }

    private func applyToTheme() {
        RCMTheme.shared.configure { tokens in
            tokens.colors = draftColors
            tokens.spacing = draftSpacing
            tokens.radius = draftRadius
            tokens.typography = draftTypography
            tokens.controlSize = draftControlSize
            tokens.heroGradient = draftHeroGradient
        }
    }

    private func exportJSON() {
        showSavePanel = true
    }
}


// MARK: - RCMThemeJSONDocument：用于文件导出的 Document 类型

public struct RCMThemeJSONDocument: FileDocument {
    public static var readableContentTypes: [UTType] { [.json] }

    public let data: Data

    public init(tokens: RCMDesignTokens) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.data = (try? encoder.encode(tokens)) ?? Data()
    }

    public init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}


#Preview{
    RCMDesignSystemPreview()
}
