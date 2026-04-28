import SwiftUI
#if canImport(AppKit)
import AppKit
#endif


// MARK: - Color 扩展：支持 hex 字符串解析

extension Color {
    /// 从 hex 字符串解析颜色，支持 "#RRGGBB" 和 "#AARRGGBB"
    public init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    /// 将 Color 转换为 hex 字符串（保留到 RGB）
    public func toHex() -> String {
        guard let components = NSColor(self).cgColor.components else { return "#000000" }
        let r = Int((components[0] * 255).rounded())
        let g = Int((components[1] * 255).rounded())
        let b = Int((components[2] * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}


// MARK: - RCMColorTokens：所有可配置颜色

public struct RCMColorTokens: Codable, Equatable, Sendable {
    public var primary: String = "#3185FF"
    public var accent: String = "#3185FF"
    public var success: String = "#27B15A"
    public var warning: String = "#F9B135"
    public var danger: String = "#E54444"

    public init() {}

    public init(primary: String, accent: String, success: String, warning: String, danger: String) {
        self.primary = primary
        self.accent = accent
        self.success = success
        self.warning = warning
        self.danger = danger
    }

    // MARK: - 运行时 Color 值

    public var primaryColor: Color { Color(hex: primary) }
    public var accentColor: Color { Color(hex: accent) }
    public var successColor: Color { Color(hex: success) }
    public var warningColor: Color { Color(hex: warning) }
    public var dangerColor: Color { Color(hex: danger) }

    // MARK: - 用 Color 直接赋值（更直觉的写法）

    /// 设置主色，支持 `tokens.colors.setPrimary(.orange)` 写法
    public mutating func setPrimary(_ color: Color) { primary = color.toHex() }
    public mutating func setAccent(_ color: Color) { accent = color.toHex() }
    public mutating func setSuccess(_ color: Color) { success = color.toHex() }
    public mutating func setWarning(_ color: Color) { warning = color.toHex() }
    public mutating func setDanger(_ color: Color) { danger = color.toHex() }

    public var accentSoft: Color { accentColor.opacity(0.12) }

    public var textPrimary: Color { Color.primary }
    public var textSecondary: Color { Color.secondary }
    public var textTertiary: Color { Color.secondary.opacity(0.72) }

    #if os(macOS)
    public var pageBackground: Color { Color(nsColor: .windowBackgroundColor) }
    public var cardBackground: Color { Color(nsColor: .controlBackgroundColor) }
    public var cardGrayBackground: Color { Color(.secondarySystemFill) }
    public var subtleFill: Color { Color(nsColor: .quaternaryLabelColor).opacity(0.08) }
    public var border: Color { Color.primary.opacity(0.10) }
    #else
    public var pageBackground: Color { Color(.systemBackground) }
    public var cardBackground: Color { Color(.secondarySystemBackground) }
    public var cardGrayBackground: Color { Color(.secondarySystemFill) }
    public var subtleFill: Color { Color(.secondarySystemFill) }
    public var border: Color { Color.primary.opacity(0.10) }
    #endif
}


// MARK: - RCMSpacingTokens

public struct RCMSpacingTokens: Codable, Equatable, Sendable {
    public var xxs: CGFloat = 4
    public var xs: CGFloat = 8
    public var sm: CGFloat = 12
    public var md: CGFloat = 16
    public var lg: CGFloat = 20
    public var xl: CGFloat = 24
    public var xxl: CGFloat = 32
    public var xxxl: CGFloat = 40

    public init() {}
}


// MARK: - RCMRadiusTokens

public struct RCMRadiusTokens: Codable, Equatable, Sendable {
    public var sm: CGFloat = 8
    public var md: CGFloat = 12
    public var lg: CGFloat = 16
    public var xl: CGFloat = 24

    public init() {}
}


// MARK: - RCMTypographyTokens（只存数值，运行时生成 Font）

public struct RCMTypographyTokens: Codable, Equatable, Sendable {
    public var heroSize: CGFloat = 30
    public var heroWeight: String = "bold"

    public var pageTitleSize: CGFloat = 17
    public var pageTitleWeight: String = "bold"

    public var sectionTitleSize: CGFloat = 15
    public var sectionTitleWeight: String = "semibold"

    public var body15Size: CGFloat = 15
    public var body15Weight: String = "regular"

    public var body15StrongSize: CGFloat = 15
    public var body15StrongWeight: String = "semibold"

    public var bodySize: CGFloat = 13
    public var bodyWeight: String = "regular"

    public var bodyStrongSize: CGFloat = 13
    public var bodyStrongWeight: String = "semibold"

    public var captionSize: CGFloat = 12
    public var captionWeight: String = "regular"

    public var captionStrongSize: CGFloat = 12
    public var captionStrongWeight: String = "semibold"

    public var monoCaptionSize: CGFloat = 11
    public var monoCaptionWeight: String = "regular"

    public init() {}

    // MARK: - 运行时 Font 值

    private func weight(from string: String) -> Font.Weight {
        switch string {
        case "bold": return .bold
        case "semibold": return .semibold
        case "medium": return .medium
        case "regular": return .regular
        case "light": return .light
        case "thin": return .thin
        default: return .regular
        }
    }

    public var hero: Font {
        .system(size: heroSize, weight: weight(from: heroWeight), design: .rounded)
    }
    public var pageTitle: Font {
        .system(size: pageTitleSize, weight: weight(from: pageTitleWeight), design: .rounded)
    }
    public var sectionTitle: Font {
        .system(size: sectionTitleSize, weight: weight(from: sectionTitleWeight))
    }
    public var body15: Font {
        .system(size: body15Size, weight: weight(from: body15Weight))
    }
    public var body15Strong: Font {
        .system(size: body15StrongSize, weight: weight(from: body15StrongWeight))
    }
    public var body: Font {
        .system(size: bodySize, weight: weight(from: bodyWeight))
    }
    public var bodyStrong: Font {
        .system(size: bodyStrongSize, weight: weight(from: bodyStrongWeight))
    }
    public var caption: Font {
        .system(size: captionSize, weight: weight(from: captionWeight))
    }
    public var captionStrong: Font {
        .system(size: captionStrongSize, weight: weight(from: captionStrongWeight))
    }
    public var monoCaption: Font {
        .system(size: monoCaptionSize, weight: weight(from: monoCaptionWeight), design: .monospaced)
    }
}


// MARK: - RCMControlSizeTokens

public struct RCMControlSizeTokens: Codable, Equatable, Sendable {
    public var buttonHeight: CGFloat = 34
    public var fieldHeight: CGFloat = 34
    public var rowMinHeight: CGFloat = 52

    public init() {}
}


// MARK: - RCMHeroGradient

public struct RCMHeroGradient: Codable, Equatable, Sendable {
    public var startColor: String = "#3185FF"
    public var endColor: String = "#0A6BFF"

    public init() {}

    public init(startColor: String, endColor: String) {
        self.startColor = startColor
        self.endColor = endColor
    }

    public var gradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: startColor), Color(hex: endColor)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}


// MARK: - RCMDesignTokens：完整设计 Token 集合

public struct RCMDesignTokens: Codable, Equatable, Sendable {
    public var colors: RCMColorTokens = RCMColorTokens()
    public var spacing: RCMSpacingTokens = RCMSpacingTokens()
    public var radius: RCMRadiusTokens = RCMRadiusTokens()
    public var typography: RCMTypographyTokens = RCMTypographyTokens()
    public var controlSize: RCMControlSizeTokens = RCMControlSizeTokens()
    public var heroGradient: RCMHeroGradient = RCMHeroGradient()

    public init() {}

    // MARK: - 预设 Hero 渐变

    public static let heroGradientBlue = RCMHeroGradient(
        startColor: "#3185FF",
        endColor: "#0A6BFF"
    )

    public static let heroGradientOrange = RCMHeroGradient(
        startColor: "#FF6B00",
        endColor: "#FF3D00"
    )

    public static let heroGradientPurple = RCMHeroGradient(
        startColor: "#8B5CF6",
        endColor: "#6D28D9"
    )
}
