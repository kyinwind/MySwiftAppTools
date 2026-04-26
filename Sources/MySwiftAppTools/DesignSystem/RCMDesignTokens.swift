import SwiftUI

enum RCMColor {
    static let primary = Color.orange                          // 主色调：橙色
    static let accent = Color(red: 0.192, green: 0.514, blue: 1.0)
    static let accentSoft = Color.accentColor.opacity(0.12)
    static let success = Color(red: 0.153, green: 0.694, blue: 0.353)
    static let warning = Color(red: 0.976, green: 0.694, blue: 0.208)
    static let danger = Color(red: 0.898, green: 0.267, blue: 0.267)

    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary = Color.secondary.opacity(0.72)

#if os(macOS)
    static let pageBackground = Color(nsColor: .windowBackgroundColor)
    static let cardBackground = Color(nsColor: .controlBackgroundColor)
    static let cardGrayBackground = Color(.secondarySystemFill)    //这个灰色比浅灰更深一点
    static let subtleFill = Color(nsColor: .quaternaryLabelColor).opacity(0.08)
    static let border = Color.primary.opacity(0.10)
#else
    static let pageBackground = Color(.systemBackground)
    static let cardBackground = Color(.secondarySystemBackground)
    static let cardGrayBackground = Color(.secondarySystemFill)
    static let subtleFill = Color(.secondarySystemFill)
    static let border = Color.primary.opacity(0.10)
#endif
}

enum RCMSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 40
}

enum RCMRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
}

enum RCMStroke {
    static let hairline: CGFloat = 1
}

enum RCMShadow {
    static let card = Color.black.opacity(0.06)
}

enum RCMTypography {
    static let hero = Font.system(size: 30, weight: .bold, design: .rounded)
    static let pageTitle = Font.system(size: 17, weight: .bold, design: .rounded)
    static let sectionTitle = Font.system(size: 15, weight: .semibold)
    static let body15 = Font.system(size: 15, weight: .regular)
    static let body15Strong = Font.system(size: 15, weight: .semibold)
    static let body = Font.system(size: 13, weight: .regular)
    static let bodyStrong = Font.system(size: 13, weight: .semibold)
    static let caption = Font.system(size: 12, weight: .regular)
    static let captionStrong = Font.system(size: 12, weight: .semibold)
    static let monoCaption = Font.system(size: 11, weight: .regular, design: .monospaced)
}

enum RCMControlSize {
    static let buttonHeight: CGFloat = 34
    static let fieldHeight: CGFloat = 34
    static let rowMinHeight: CGFloat = 52
}
