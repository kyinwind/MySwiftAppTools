import SwiftUI

// MARK: - 按钮角色枚举
/// 定义按钮的视觉风格角色
public enum RCMButtonRole {
    case primary    // 主要按钮：橙色填充背景，白色文字，无边框
    case secondary  // 次要按钮：卡片背景色，带边框
    case subtle     // 柔和按钮：极浅的背景色，低对比度
    case destructive // 危险按钮：红色主题，表示删除等危险操作
}

// MARK: - 按钮样式
/// 自定义按钮样式，支持多种角色和全宽选项
public struct RCMButtonStyle: ButtonStyle {
    let role: RCMButtonRole       // 按钮角色，决定颜色和边框
    let fullWidth: Bool           // 是否占满宽度
    let isDisabled: Bool          // 是否禁用状态

    public init(role: RCMButtonRole = .secondary, fullWidth: Bool? = nil, isDisabled: Bool = false) {
        self.role = role
        // Buttons default to content width; pass fullWidth explicitly for rare form-style actions.
        self.fullWidth = fullWidth ?? false
        self.isDisabled = isDisabled
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(RCMTypography.bodyStrong)
            // 按下时文字颜色略微变暗
            .foregroundStyle(foregroundColor.opacity(isPressedOpacity(configuration.isPressed)))
            // 全宽模式下撑满容器
            .frame(maxWidth: fullWidth ? .infinity : nil)
            // 固定高度
            .frame(height: RCMControlSize.buttonHeight)
            // 左右内边距
            .padding(.horizontal, RCMSpacing.md)
            // 动态背景（按下时加深）
            .background(background(configuration.isPressed))
            // 边框
            .overlay(border)
            // 圆角裁剪
            .clipShape(RoundedRectangle(cornerRadius: RCMRadius.md, style: .continuous))
            // 按下时轻微缩小反馈
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            // 按下动画：120ms 缓出
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    /// 按压/禁用时的透明度
    private func isPressedOpacity(_ isPressed: Bool) -> Double {
        if isDisabled { return 0.72 }
        return isPressed ? 0.92 : 1.0
    }

    /// 根据角色返回文字颜色
    private var foregroundColor: Color {
        switch role {
        case .primary:
            return .white  // 主要按钮用白色文字
        case .secondary, .subtle:
            return RCMColor.textPrimary  // 次要和柔和按钮用主文字色
        case .destructive:
            return RCMColor.danger  // 危险按钮用红色
        }
    }

    /// 根据角色和按压状态返回背景
    @ViewBuilder
    private func background(_ isPressed: Bool) -> some View {
        let opacity = isPressed ? 0.86 : 1.0

        switch role {
        case .primary:
            // 主要按钮：橙色填充
            RoundedRectangle(cornerRadius: RCMRadius.md, style: .continuous)
                .fill(isDisabled ? Color.gray.opacity(0.55) : RCMColor.shared.primary.opacity(opacity))
        case .secondary:
            // 次要按钮：卡片背景色
            RoundedRectangle(cornerRadius: RCMRadius.md, style: .continuous)
                .fill(RCMColor.cardBackground.opacity(isPressed ? 0.9 : 1.0))
        case .subtle:
            // 柔和按钮：极浅的背景
            RoundedRectangle(cornerRadius: RCMRadius.md, style: .continuous)
                .fill(RCMColor.subtleFill.opacity(isPressed ? 0.9 : 1.0))
        case .destructive:
            // 危险按钮：极浅的红色背景
            RoundedRectangle(cornerRadius: RCMRadius.md, style: .continuous)
                .fill(RCMColor.danger.opacity(0.08))
        }
    }

    /// 边框视图
    private var border: some View {
        RoundedRectangle(cornerRadius: RCMRadius.md, style: .continuous)
            .stroke(borderColor, lineWidth: RCMStroke.hairline)
    }

    /// 根据角色返回边框颜色
    private var borderColor: Color {
        switch role {
        case .primary:
            return .clear  // 主要按钮无边框
        case .secondary, .subtle:
            return RCMColor.border  // 次要和柔和按钮用标准边框
        case .destructive:
            return RCMColor.danger.opacity(0.18)  // 危险按钮用淡红色边框
        }
    }
}

// MARK: - Button 扩展
public extension Button {
    /// 快速应用 RCM 按钮样式的便捷方法
    /// - Parameters:
    ///   - role: 按钮角色，默认为 secondary
    ///   - fullWidth: 是否占满宽度，默认不全宽；只有表单式大按钮需要显式传 true
    ///   - isDisabled: 是否禁用状态，默认为 false
    /// - Returns: 应用了 RCMButtonStyle 的视图
    @MainActor
    func rcmButton(_ role: RCMButtonRole = .secondary, fullWidth: Bool? = nil, isDisabled: Bool = false) -> some View {
        buttonStyle(RCMButtonStyle(role: role, fullWidth: fullWidth, isDisabled: isDisabled))
    }
}

// MARK: - 侧边栏图标组件
/// 侧边栏菜单项中使用的彩色图标
/// 由彩色圆角矩形背景 + 白色 SF Symbol 图标组成
public struct RCMSidebarIcon: View {
    let systemName: String  // SF Symbol 名称
    let tint: Color          // 背景颜色
    let size: IconSize       // 图标尺寸

    public init(systemName: String, tint: Color, size: IconSize = .medium) {
        self.systemName = systemName
        self.tint = tint
        self.size = size
    }

    /// 图标尺寸枚举，提供 small/medium/large 三种尺寸
    public enum IconSize {
        case small   // 24pt 背景, 11pt 图标
        case medium  // 28pt 背景, 14pt 图标
        case large   // 32pt 背景, 16pt 图标

        /// 图标本身的字体大小
        public var iconSize: CGFloat {
            switch self {
            case .small:  return 11
            case .medium: return 14
            case .large:  return 16
            }
        }

        /// 外层背景的尺寸
        public var frameSize: CGFloat {
            switch self {
            case .small:  return 24
            case .medium: return 28
            case .large:  return 32
            }
        }
    }

    public var body: some View {
        ZStack {
            // 圆角矩形背景，带颜色
            RoundedRectangle(cornerRadius: size.frameSize * 0.22)
                .fill(tint.opacity(0.9))
                .frame(width: size.frameSize, height: size.frameSize)

            // 白色 SF Symbol 图标
            Image(systemName: systemName)
                .font(.system(size: size.iconSize, weight: .medium))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - 预设图标颜色
/// RCMSidebarIcon 的预设颜色集合，方便统一使用
public extension RCMSidebarIcon {
    enum PresetTint {
        public static let gray   = Color.gray
        public static let blue   = RCMColor.accent      // 主题蓝色
        public static let green  = RCMColor.success     // 成功绿色
        public static let orange = RCMColor.warning     // 警告橙色
        public static let red    = RCMColor.danger      // 危险红色
        public static let purple = Color.purple
        public static let pink   = Color.pink
        public static let teal   = Color.teal
        public static let indigo = Color.indigo
    }
}

// MARK: - 状态徽章组件
/// 用于显示状态标签的胶囊形徽章，如"已激活"、"Pro"等
/// 支持本地化字符串和普通字符串两种构造方式
public struct RCMStatusBadge: View {
    private let titleKey: LocalizedStringKey?  // 本地化字符串（优先使用）
    private let titleText: String?              // 普通字符串
    let tone: Tone                               // 色调主题

    /// 使用本地化字符串构造
    public init(title: LocalizedStringKey, tone: Tone) {
        self.titleKey = title
        self.titleText = nil
        self.tone = tone
    }

    /// 使用普通字符串构造
    public init(text: String, tone: Tone) {
        self.titleKey = nil
        self.titleText = text
        self.tone = tone
    }

    /// 徽章色调枚举
    public enum Tone {
        case neutral   // 中性：灰色文字和背景
        case success   // 成功：绿色
        case warning   // 警告：橙色
        case accent    // 主题色：蓝色

        /// 前景色（文字颜色）
        public var foreground: Color {
            switch self {
            case .neutral:
                return RCMColor.textSecondary
            case .success:
                return RCMColor.success
            case .warning:
                return RCMColor.warning
            case .accent:
                return RCMColor.accent
            }
        }

        /// 背景色：前景色的 12% 透明度
        public var background: Color {
            foreground.opacity(0.12)
        }
    }

    public var body: some View {
        Group {
            if let titleKey {
                Text(titleKey)
            } else if let titleText {
                Text(titleText)
            }
        }
            .font(RCMTypography.captionStrong)
            .foregroundStyle(tone.foreground)
            .padding(.horizontal, RCMSpacing.sm)  // 左右内边距
            .frame(height: 24)                    // 固定高度
            .background(tone.background)
            .clipShape(Capsule())                 // 胶囊形状
    }
}

// MARK: - 统计数字徽章组件
/// 用于显示数字统计的胶囊形徽章，如下载量、评分等
/// 与 RCMStatusBadge 类似，但增加了 light/dark 两种色调
public struct RCMStatBadge: View {
    private let titleKey: LocalizedStringKey?
    private let titleText: String?
    public let tone: Tone

    /// 使用本地化字符串构造
    public init(title: LocalizedStringKey, tone: Tone) {
        self.titleKey = title
        self.titleText = nil
        self.tone = tone
    }

    /// 使用普通字符串构造
    public init(text: String, tone: Tone) {
        self.titleKey = nil
        self.titleText = text
        self.tone = tone
    }

    /// 徽章色调枚举，比 RCMStatusBadge 多 light/dark
    public enum Tone {
        case neutral  // 中性：灰色
        case light    // 亮色：绿色
        case dark     // 暗色：卡片背景色
        case accent   // 主题色：蓝色

        /// 前景色
        public var foreground: Color {
            switch self {
            case .neutral:
                return RCMColor.textSecondary
            case .dark:
                return RCMColor.cardBackground
            case .light:
                return RCMColor.success
            case .accent:
                return RCMColor.accent
            }
        }

        /// 背景色：前景色的 12% 透明度
        public var background: Color {
            foreground.opacity(0.12)
        }
    }

    public var body: some View {
        Group {
            if let titleKey {
                Text(titleKey)
            } else if let titleText {
                Text(titleText)
            }
        }
            .font(RCMTypography.captionStrong)
            .foregroundStyle(tone.foreground)
            .padding(.horizontal, RCMSpacing.sm)
            .frame(height: 24)
            .background(tone.background)
            .clipShape(Capsule())
    }
}
