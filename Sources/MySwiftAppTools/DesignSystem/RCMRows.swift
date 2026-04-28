import SwiftUI

// MARK: - RCMSettingRow

public struct RCMSettingRow<Trailing: View>: View {
    let title: LocalizedStringKey
    let subtitle: String?
    let trailing: Trailing

    public init(
        _ title: LocalizedStringKey,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(alignment: .center, spacing: RCMTheme.shared.spacing.md) {
            VStack(alignment: .leading, spacing: RCMTheme.shared.spacing.xxs) {
                Text(title)
                    .font(RCMTheme.shared.typography.bodyStrong)
                    .foregroundStyle(RCMTheme.shared.colors.textPrimary)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(RCMTheme.shared.typography.caption)
                        .foregroundStyle(RCMTheme.shared.colors.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer(minLength: RCMTheme.shared.spacing.md)
            trailing
        }
        .frame(minHeight: RCMTheme.shared.controlSize.rowMinHeight)
    }
}

// MARK: - RCMValueRow

public struct RCMValueRow: View {
    let title: LocalizedStringKey
    let value: String
    let tone: Color

    public init(_ title: LocalizedStringKey, value: String, tone: Color = RCMTheme.shared.colors.textPrimary) {
        self.title = title
        self.value = value
        self.tone = tone
    }

    public var body: some View {
        HStack(spacing: RCMTheme.shared.spacing.md) {
            Text(title)
                .font(RCMTheme.shared.typography.body)
                .foregroundStyle(RCMTheme.shared.colors.textSecondary)

            Spacer()

            Text(value)
                .font(RCMTheme.shared.typography.bodyStrong)
                .foregroundStyle(tone)
        }
        .frame(minHeight: 28)
    }
}

// MARK: - RCMInlineField

public struct RCMInlineField<Content: View>: View {
    let label: LocalizedStringKey
    let content: Content

    public init(_ label: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: RCMTheme.shared.spacing.xs) {
            RCMLabelText(label)
            content
        }
    }
}
