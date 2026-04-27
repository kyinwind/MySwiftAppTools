import SwiftUI


// MARK: - App 启动时配置
// 在 App.init 或 AppDelegate.applicationDidFinishLaunching 中：
// RCMColor.shared.primary = .blue  // 每个 App 自行设置

public final class RCMColor {
    @MainActor public static let shared = RCMColor()
    
    // 可配置的主色调，每个 App 启动时设置
    public var primary: Color = Color.blue
    
    public static let accent = Color(red: 0.192, green: 0.514, blue: 1.0)
    public static let accentSoft = Color.accentColor.opacity(0.12)
    public static let success = Color(red: 0.153, green: 0.694, blue: 0.353)
    public static let warning = Color(red: 0.976, green: 0.694, blue: 0.208)
    public static let danger = Color(red: 0.898, green: 0.267, blue: 0.267)
    
    public static let textPrimary = Color.primary
    public static let textSecondary = Color.secondary
    public static let textTertiary = Color.secondary.opacity(0.72)
    
#if os(macOS)
    public static let pageBackground = Color(nsColor: .windowBackgroundColor)
    public static let cardBackground = Color(nsColor: .controlBackgroundColor)
    public static let cardGrayBackground = Color(.secondarySystemFill)
    public static let subtleFill = Color(nsColor: .quaternaryLabelColor).opacity(0.08)
    public static let border = Color.primary.opacity(0.10)
#else
    public static let pageBackground = Color(.systemBackground)
    public static let cardBackground = Color(.secondarySystemBackground)
    public static let cardGrayBackground = Color(.secondarySystemFill)
    public static let subtleFill = Color(.secondarySystemFill)
    public static let border = Color.primary.opacity(0.10)
#endif
    
    public init() {}
}

public enum RCMSpacing {
    public static let xxs: CGFloat = 4
    public static let xs: CGFloat = 8
    public static let sm: CGFloat = 12
    public static let md: CGFloat = 16
    public static let lg: CGFloat = 20
    public static let xl: CGFloat = 24
    public static let xxl: CGFloat = 32
    public static let xxxl: CGFloat = 40
}

public enum RCMRadius {
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 24
}

public enum RCMStroke {
    public static let hairline: CGFloat = 1
}

public enum RCMShadow {
    public static let card = Color.black.opacity(0.06)
}

public enum RCMTypography {
    public static let hero = Font.system(size: 30, weight: .bold, design: .rounded)
    public static let pageTitle = Font.system(size: 17, weight: .bold, design: .rounded)
    public static let sectionTitle = Font.system(size: 15, weight: .semibold)
    public static let body15 = Font.system(size: 15, weight: .regular)
    public static let body15Strong = Font.system(size: 15, weight: .semibold)
    public static let body = Font.system(size: 13, weight: .regular)
    public static let bodyStrong = Font.system(size: 13, weight: .semibold)
    public static let caption = Font.system(size: 12, weight: .regular)
    public static let captionStrong = Font.system(size: 12, weight: .semibold)
    public static let monoCaption = Font.system(size: 11, weight: .regular, design: .monospaced)
}

public enum RCMControlSize {
    public static let buttonHeight: CGFloat = 34
    public static let fieldHeight: CGFloat = 34
    public static let rowMinHeight: CGFloat = 52
}
