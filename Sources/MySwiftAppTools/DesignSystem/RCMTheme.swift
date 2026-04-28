import SwiftUI


// MARK: - RCMThemeBuilder：用于闭包配置的 builder

@resultBuilder
public struct RCMThemeBuilder {
    public static func buildBlock(_ components: Void...) -> Void {}
    public static func buildEither<T>(truthy: T) -> T { truthy }
    public static func buildEither<T>(falsey: T) -> T { falsey }
}


// MARK: - RCMThemeError

public enum RCMThemeError: LocalizedError {
    case jsonDecodingFailed(Error)
    case fileNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .jsonDecodingFailed(let error):
            return "JSON 解码失败: \(error.localizedDescription)"
        case .fileNotFound(let path):
            return "文件未找到: \(path)"
        }
    }
}


// MARK: - RCMTheme

/// Design System 统一配置入口
///
/// 使用方式：
/// ```swift
/// // App 初始化时配置主题
/// RCMTheme.shared.configure { tokens in
///     tokens.colors.primary = "#FF6B00"
/// }
/// ```
public final class RCMTheme: @unchecked Sendable {

    /// 全局单例，在 App 启动阶段（任何 UI 代码之前）即可访问
    ///
    /// 使用 `nonisolated(unsafe)` 允许在非主线程初始化，
    /// 但后续所有配置和读取操作都应在主线程进行（macOS UI 的标准要求）。
    public nonisolated(unsafe) static let shared = RCMTheme()

    /// 当前生效的设计 Token
    public var tokens: RCMDesignTokens = RCMDesignTokens()

    private init() {}

    // MARK: - 配置方法

    /// 通过闭包配置 Token（链式配置）
    ///
    /// ```swift
    /// RCMTheme.shared.configure { tokens in
    ///     tokens.colors.primary = "#FF6B00"
    ///     tokens.spacing.lg = 24
    /// }
    /// ```
    public func configure(_ block: (inout RCMDesignTokens) -> Void) {
        block(&tokens)
    }

    /// 通过 JSON Data 配置 Token
    ///
    /// ```swift
    /// let data = try Data(contentsOf: url)
    /// try RCMTheme.shared.configure(jsonData: data)
    /// ```
    public func configure(jsonData: Data) throws {
        do {
            tokens = try JSONDecoder().decode(RCMDesignTokens.self, from: jsonData)
        } catch {
            throw RCMThemeError.jsonDecodingFailed(error)
        }
    }

    /// 通过文件 URL 加载 JSON 配置
    ///
    /// ```swift
    /// let url = Bundle.main.url(forResource: "theme", withExtension: "json")!
    /// try RCMTheme.shared.configure(jsonFileURL: url)
    /// ```
    public func configure(jsonFileURL url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw RCMThemeError.fileNotFound(url.path)
        }
        let data = try Data(contentsOf: url)
        try configure(jsonData: data)
    }

    /// 从 Bundle 内的 JSON 资源文件加载配置
    ///
    /// ```swift
    /// // 从 MyAppTheme.json 加载（扩展名自动追加）
    /// try RCMTheme.shared.configure(jsonResource: "MyAppTheme")
    /// ```
    public func configure(jsonResource name: String, bundle: Bundle = .main) throws {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw RCMThemeError.fileNotFound("'\(name).json' in bundle")
        }
        try configure(jsonFileURL: url)
    }

    /// 应用预设主题
    ///
    /// ```swift
    /// RCMTheme.shared.applyPreset(.rightClickMate)
    /// ```
    public func applyPreset(_ preset: RCMPresetTheme) {
        tokens = preset.tokens
    }

    // MARK: - 便捷访问别名

    /// 颜色 Token 快捷访问
    public var colors: RCMColorTokens { tokens.colors }

    /// 间距 Token 快捷访问
    public var spacing: RCMSpacingTokens { tokens.spacing }

    /// 圆角 Token 快捷访问
    public var radius: RCMRadiusTokens { tokens.radius }

    /// 字体 Token 快捷访问
    public var typography: RCMTypographyTokens { tokens.typography }

    /// 控件尺寸 Token 快捷访问
    public var controlSize: RCMControlSizeTokens { tokens.controlSize }

    /// Hero 渐变 Token 快捷访问
    public var heroGradient: RCMHeroGradient { tokens.heroGradient }

    /// stroke Token 快捷访问
    public var stroke: RCMStrokeTokens { tokens.stroke }
    
    /// 阴影 Token 快捷访问
    public var shadow: RCMShadowTokens { tokens.shadow }

    // MARK: - 导出 JSON

    /// 将当前 Token 导出为 JSON Data
    public func exportJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(tokens)
    }

    /// 将当前 Token 导出为格式化 JSON 字符串
    public func exportJSONString() throws -> String {
        let data = try exportJSON()
        guard let string = String(data: data, encoding: .utf8) else {
            throw RCMThemeError.jsonDecodingFailed(
                NSError(domain: "RCMTheme", code: 0, userInfo: [NSLocalizedDescriptionKey: "无法将 JSON Data 转换为字符串"])
            )
        }
        return string
    }
}


// MARK: - RCMPresetTheme：预设主题

public struct RCMPresetTheme: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let tokens: RCMDesignTokens

    public init(id: String, name: String, tokens: RCMDesignTokens) {
        self.id = id
        self.name = name
        self.tokens = tokens
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: RCMPresetTheme, rhs: RCMPresetTheme) -> Bool {
        lhs.id == rhs.id
    }

    // MARK: - 内置预设

    /// 默认蓝色主题
    public static let `default` = RCMPresetTheme(
        id: "default",
        name: "默认蓝色",
        tokens: {
            var t = RCMDesignTokens()
            t.colors.primary = "#3185FF"
            t.colors.accent = "#3185FF"
            t.heroGradient = RCMDesignTokens.heroGradientBlue
            return t
        }()
    )

    /// RightClickMate 橙色主题
    public static let rightClickMate = RCMPresetTheme(
        id: "rightClickMate",
        name: "RightClickMate",
        tokens: {
            var t = RCMDesignTokens()
            t.colors.primary = "#FF6B00"
            t.colors.accent = "#FF6B00"
            t.colors.success = "#27B15A"
            t.colors.warning = "#F9B135"
            t.colors.danger = "#E54444"
            t.heroGradient = RCMDesignTokens.heroGradientOrange
            return t
        }()
    )

    /// VideoHero 紫色专业主题
    public static let videoHero = RCMPresetTheme(
        id: "videoHero",
        name: "VideoHero",
        tokens: {
            var t = RCMDesignTokens()
            t.colors.primary = "#8B5CF6"
            t.colors.accent = "#8B5CF6"
            t.colors.success = "#10B981"
            t.colors.warning = "#F59E0B"
            t.colors.danger = "#EF4444"
            t.heroGradient = RCMDesignTokens.heroGradientPurple
            return t
        }()
    )

    /// 所有内置预设
    public static let allPresets: [RCMPresetTheme] = [
        .default,
        .rightClickMate,
        .videoHero
    ]
}


// MARK: - View 修饰器（可选的便捷扩展）

extension View {
    /// 直接应用 RCMTheme 的 Token 到视图
    public func rcmThemed() -> some View {
        self.modifier(RCMThemeModifier())
    }
}

private struct RCMThemeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
    }
}
