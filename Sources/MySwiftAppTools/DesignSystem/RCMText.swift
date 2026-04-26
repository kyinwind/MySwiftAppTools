import SwiftUI

//macOS SwiftUI 中会自动切换的系统颜色：
//
//背景色：
//
//Color(.textBackgroundColor) / .controlBackgroundColor / .windowBackgroundColor
//.secondarySystemBackground / .tertiarySystemBackground
//.underPageBackground / .underWindowBackground
//文字色：
//
//.labelColor / .secondaryLabelColor / .tertiaryLabelColor
//.quaternaryLabelColor
//其他：
//
//.separatorColor / .opaqueSeparatorColor - 分隔线
//.selectionColor - 选中色
//.controlColor - 控件色
//macOS 特有：
//
//.alternatingContentBackgroundColors
//建议使用 Color(.controlBackgroundColor) 作为卡片背景，Color(.labelColor) 作为文字色，这样在亮色/暗色模式下都会自动适配。
//页面的 title
struct RCMPageTitle: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey?

    init(_ title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RCMSpacing.xs) {
            Text(title)
                .font(RCMTypography.pageTitle)
                .foregroundStyle(RCMColor.textPrimary)

            if let subtitle {
                Text(subtitle)
                    .font(RCMTypography.body)
                    .foregroundStyle(RCMColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
//每一页里面每一个章节的 title
struct RCMSectionTitle: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey?

    init(_ title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RCMSpacing.xxs) {
            Text(title)
                .font(RCMTypography.sectionTitle)
                .foregroundStyle(RCMColor.textPrimary)

            if let subtitle {
                Text(subtitle)
                    .font(RCMTypography.caption)
                    .foregroundStyle(RCMColor.textSecondary)
                    .lineLimit(3)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct RCMLabelText: View {
    let text: LocalizedStringKey

    init(_ text: LocalizedStringKey) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(RCMTypography.captionStrong)
            .foregroundStyle(RCMColor.textSecondary)
            .textCase(nil)
    }
}

struct RCMCaptionText: View {
    let text: LocalizedStringKey

    init(_ text: LocalizedStringKey) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(RCMTypography.caption)
            .foregroundStyle(RCMColor.textSecondary)
    }
}

struct RCMMonoText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(RCMTypography.monoCaption)
            .foregroundStyle(RCMColor.textSecondary)
            .lineLimit(1)
            .truncationMode(.middle)
    }
}
