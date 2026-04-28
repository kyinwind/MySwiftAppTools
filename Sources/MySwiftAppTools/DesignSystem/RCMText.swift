import SwiftUI

// macOS SwiftUI 中会自动切换的系统颜色：
//
// 背景色：
// Color(.textBackgroundColor) / .controlBackgroundColor / .windowBackgroundColor
// .secondarySystemBackground / .tertiarySystemBackground
// .underPageBackground / .underWindowBackground
//
// 文字色：
// .labelColor / .secondaryLabelColor / .tertiaryLabelColor
// .quaternaryLabelColor
//
// 其他：
// .separatorColor / .opaqueSeparatorColor - 分隔线
// .selectionColor - 选中色
// .controlColor - 控件色
//
// macOS 特有：
// .alternatingContentBackgroundColors
//
// 建议使用 Color(.controlBackgroundColor) 作为卡片背景，Color(.labelColor) 作为文字色，
// 这样在亮色/暗色模式下都会自动适配。

// MARK: - RCMPageTitle

/// 页面的大标题（用于页面顶部的标题区域）
public struct RCMPageTitle: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey?

    public init(_ title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: RCMTheme.shared.spacing.xs) {
            Text(title)
                .font(RCMTheme.shared.typography.pageTitle)
                .foregroundStyle(RCMTheme.shared.colors.textPrimary)

            if let subtitle {
                Text(subtitle)
                    .font(RCMTheme.shared.typography.body)
                    .foregroundStyle(RCMTheme.shared.colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - RCMSectionTitle

/// 章节标题（用于页面内每个区块的标题）
public struct RCMSectionTitle: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey?

    public init(_ title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: RCMTheme.shared.spacing.xxs) {
            Text(title)
                .font(RCMTheme.shared.typography.sectionTitle)
                .foregroundStyle(RCMTheme.shared.colors.textPrimary)

            if let subtitle {
                Text(subtitle)
                    .font(RCMTheme.shared.typography.caption)
                    .foregroundStyle(RCMTheme.shared.colors.textSecondary)
                    .lineLimit(3)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - RCMLabelText

/// 表单标签文字（次要层级，用于 label）
public struct RCMLabelText: View {
    let text: LocalizedStringKey

    public init(_ text: LocalizedStringKey) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(RCMTheme.shared.typography.captionStrong)
            .foregroundStyle(RCMTheme.shared.colors.textSecondary)
            .textCase(nil)
    }
}

// MARK: - RCMCaptionText

/// 说明文字（最次要层级，用于 caption）
public struct RCMCaptionText: View {
    let text: LocalizedStringKey

    public init(_ text: LocalizedStringKey) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(RCMTheme.shared.typography.caption)
            .foregroundStyle(RCMTheme.shared.colors.textSecondary)
    }
}

// MARK: - RCMMonoText

/// 等宽文字（用于路径、代码等）
public struct RCMMonoText: View {
    let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(RCMTheme.shared.typography.monoCaption)
            .foregroundStyle(RCMTheme.shared.colors.textSecondary)
            .lineLimit(1)
            .truncationMode(.middle)
    }
}
