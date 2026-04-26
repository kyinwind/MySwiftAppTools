import SwiftUI

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
        HStack(alignment: .center, spacing: RCMSpacing.md) {
            VStack(alignment: .leading, spacing: RCMSpacing.xxs) {
                Text(title)
                    .font(RCMTypography.bodyStrong)
                    .foregroundStyle(RCMColor.textPrimary)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(RCMTypography.caption)
                        .foregroundStyle(RCMColor.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer(minLength: RCMSpacing.md)
            trailing
        }
        .frame(minHeight: RCMControlSize.rowMinHeight)
    }
}

public struct RCMValueRow: View {
    let title: LocalizedStringKey
    let value: String
    let tone: Color

    public init(_ title: LocalizedStringKey, value: String, tone: Color = RCMColor.textPrimary) {
        self.title = title
        self.value = value
        self.tone = tone
    }

    public var body: some View {
        HStack(spacing: RCMSpacing.md) {
            Text(title)
                .font(RCMTypography.body)
                .foregroundStyle(RCMColor.textSecondary)

            Spacer()

            Text(value)
                .font(RCMTypography.bodyStrong)
                .foregroundStyle(tone)
        }
        .frame(minHeight: 28)
    }
}

public struct RCMInlineField<Content: View>: View {
    let label: LocalizedStringKey
    let content: Content

    public init(_ label: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: RCMSpacing.xs) {
            RCMLabelText(label)
            content
        }
    }
}
