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
//
// 公开属性直接是 Color 类型，方便使用。
// JSON 编解码通过自定义 Codable 实现（内部用 hex 字符串中转）。

public struct RCMColorTokens: Codable, Equatable, Sendable {
    public var primary: Color = .blue
    public var accent: Color = .blue
    public var success: Color = .green
    public var warning: Color = .orange
    public var danger: Color = .red

    public init() {}

    /// 用 Color 直接初始化
    public init(primary: Color = .blue, accent: Color = .blue,
                success: Color = .green, warning: Color = .orange, danger: Color = .red) {
        self.primary = primary
        self.accent = accent
        self.success = success
        self.warning = warning
        self.danger = danger
    }

    // MARK: - 派生色

    public var accentSoft: Color { accent.opacity(0.12) }
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

    // MARK: - Codable（hex 字符串 ↔ Color）

    private enum CodingKeys: String, CodingKey {
        case primary, accent, success, warning, danger
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // JSON 中存的是 hex 字符串，解码时转成 Color
        primary  = try Color(hex: container.decode(String.self, forKey: .primary))
        accent   = try Color(hex: container.decode(String.self, forKey: .accent))
        success  = try Color(hex: container.decode(String.self, forKey: .success))
        warning  = try Color(hex: container.decode(String.self, forKey: .warning))
        danger   = try Color(hex: container.decode(String.self, forKey: .danger))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // 编码时将 Color 转回 hex 字符串
        try container.encode(primary.toHex(),  forKey: .primary)
        try container.encode(accent.toHex(),   forKey: .accent)
        try container.encode(success.toHex(),  forKey: .success)
        try container.encode(warning.toHex(),  forKey: .warning)
        try container.encode(danger.toHex(),   forKey: .danger)
    }
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

// MARK: - RCMStrokeTokens

public struct RCMStrokeTokens: Codable, Equatable, Sendable {
    public var hairline: CGFloat = 1
    public init() {}
}
// MARK: - RCMShadowTokens

public struct RCMShadowTokens: Codable, Equatable, Sendable {
    /// 阴影颜色（hex 字符串）
    public var color: String = "#000000"
    /// 透明度 (0.0 ~ 1.0)
    public var opacity: Double = 0.06
    /// 模糊半径
    public var radius: CGFloat = 18
    /// X 偏移
    public var x: CGFloat = 0
    /// Y 偏移
    public var y: CGFloat = 10

    public init() {}

    public init(color: String, opacity: Double = 0.06, radius: CGFloat = 18, x: CGFloat = 0, y: CGFloat = 10) {
        self.color = color
        self.opacity = opacity
        self.radius = radius
        self.x = x
        self.y = y
    }

    // MARK: - 运行时 Shadow 值

    /// 阴影颜色（已应用透明度），用于 `.shadow(color:radius:x:y:)`
    public var shadowColor: Color { Color(hex: color).opacity(opacity) }

    // MARK: - 预设

    /// 默认卡片阴影：微弱、大范围
    public static let card = RCMShadowTokens(
        color: "#000000", opacity: 0.06, radius: 18, x: 0, y: 10
    )

    /// 轻量阴影：更淡更小
    public static let subtle = RCMShadowTokens(
        color: "#000000", opacity: 0.04, radius: 8, x: 0, y: 2
    )

    /// 强调阴影：更深更明显（用于浮层）
    public static let prominent = RCMShadowTokens(
        color: "#000000", opacity: 0.15, radius: 24, x: 0, y: 16
    )
}

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
    public var startColor: Color = .blue
    public var endColor: Color = .blue

    public init() {}

    /// 用 Color 直接初始化
    public init(startColor: Color, endColor: Color) {
        self.startColor = startColor
        self.endColor = endColor
    }

    public var gradient: LinearGradient {
        LinearGradient(
            colors: [startColor, endColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Codable（hex 字符串 ↔ Color）

    private enum CodingKeys: String, CodingKey { case startColor, endColor }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        startColor = try Color(hex: container.decode(String.self, forKey: .startColor))
        endColor   = try Color(hex: container.decode(String.self, forKey: .endColor))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(startColor.toHex(), forKey: .startColor)
        try container.encode(endColor.toHex(),   forKey: .endColor)
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
    public var stroke:RCMStrokeTokens = RCMStrokeTokens()
    public var shadow: RCMShadowTokens = RCMShadowTokens()

    public init() {}

    // MARK: - 预设 Hero 渐变

    public static let heroGradientBlue = RCMHeroGradient(
        startColor: Color(hex: "#3185FF"),
        endColor:   Color(hex: "#0A6BFF")
    )

    public static let heroGradientOrange = RCMHeroGradient(
        startColor: Color(hex: "#FF6B00"),
        endColor:   Color(hex: "#FF3D00")
    )

    public static let heroGradientPurple = RCMHeroGradient(
        startColor: Color(hex: "#8B5CF6"),
        endColor:   Color(hex: "#6D28D9")
    )
}
