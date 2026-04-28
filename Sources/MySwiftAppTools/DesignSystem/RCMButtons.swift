import SwiftUI

// MARK: - RCMButtonStyle 样式定义

public struct RCMPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(RCMTheme.shared.typography.bodyStrong)
            .foregroundColor(.white)
            .frame(height: RCMTheme.shared.controlSize.buttonHeight)
            .padding(.horizontal, RCMTheme.shared.spacing.md)
            .background(
                RoundedRectangle(cornerRadius: RCMTheme.shared.radius.md)
                    .fill(RCMTheme.shared.colors.primaryColor)
            )
            .opacity(isEnabled ? (isHovered ? 0.85 : 1.0) : 0.5)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

public struct RCMSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(RCMTheme.shared.typography.bodyStrong)
            .foregroundColor(RCMTheme.shared.colors.primaryColor)
            .frame(height: RCMTheme.shared.controlSize.buttonHeight)
            .padding(.horizontal, RCMTheme.shared.spacing.md)
            .background(
                RoundedRectangle(cornerRadius: RCMTheme.shared.radius.md)
                    .stroke(RCMTheme.shared.colors.primaryColor, lineWidth: 1.5)
            )
            .opacity(isEnabled ? (isHovered ? 0.85 : 1.0) : 0.5)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

public struct RCMSoftButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(RCMTheme.shared.typography.bodyStrong)
            .foregroundColor(RCMTheme.shared.colors.primaryColor)
            .frame(height: RCMTheme.shared.controlSize.buttonHeight)
            .padding(.horizontal, RCMTheme.shared.spacing.md)
            .background(
                RoundedRectangle(cornerRadius: RCMTheme.shared.radius.md)
                    .fill(RCMTheme.shared.colors.accentSoft)
            )
            .opacity(isEnabled ? (isHovered ? 0.85 : 1.0) : 0.5)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

public struct RCMDangerButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(RCMTheme.shared.typography.bodyStrong)
            .foregroundColor(.white)
            .frame(height: RCMTheme.shared.controlSize.buttonHeight)
            .padding(.horizontal, RCMTheme.shared.spacing.md)
            .background(
                RoundedRectangle(cornerRadius: RCMTheme.shared.radius.md)
                    .fill(RCMTheme.shared.colors.dangerColor)
            )
            .opacity(isEnabled ? (isHovered ? 0.85 : 1.0) : 0.5)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

// MARK: - RCMButton：通用按钮

public struct RCMButton: View {
    public enum Role {
        case primary
        case secondary
        case soft
        case danger
    }

    private let role: Role
    private let action: () -> Void
    private let label: () -> AnyView

    public init(
        _ role: Role = .primary,
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> some View
    ) {
        self.role = role
        self.action = action
        self.label = { AnyView(label()) }
    }

    public var body: some View {
        Group {
            switch role {
            case .primary:
                Button(action: action) { label() }
                    .buttonStyle(RCMPrimaryButtonStyle())
            case .secondary:
                Button(action: action) { label() }
                    .buttonStyle(RCMSecondaryButtonStyle())
            case .soft:
                Button(action: action) { label() }
                    .buttonStyle(RCMSoftButtonStyle())
            case .danger:
                Button(action: action) { label() }
                    .buttonStyle(RCMDangerButtonStyle())
            }
        }
    }
}

// MARK: - RCMSidebarIcon

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

// MARK: - RCMSidebarIconPresetTint

public enum RCMSidebarIconPresetTint {
    case blue, green, orange, red, gray

    public var color: Color {
        switch self {
        case .blue: return RCMTheme.shared.colors.primaryColor
        case .green: return RCMTheme.shared.colors.successColor
        case .orange: return RCMTheme.shared.colors.warningColor
        case .red: return RCMTheme.shared.colors.dangerColor
        case .gray: return .secondary
        }
    }
}

// MARK: - RCMBadge

public struct RCMBadge: View {
    public enum Style {
        case neutral   // 中性：灰色
        case accent    // 主题色：跟随 primary
        case success   // 成功：绿色
        case warning   // 警告：橙色
        case danger    // 危险：红色
    }

    private let text: String
    private let style: Style

    public init(_ text: String, style: Style = .accent) {
        self.text = text
        self.style = style
    }

    public var body: some View {
        Text(text)
            .font(RCMTheme.shared.typography.captionStrong)
            .foregroundColor(foregroundColor)
            .padding(.horizontal, RCMTheme.shared.spacing.xs)
            .padding(.vertical, RCMTheme.shared.spacing.xxs)
            .background(
                Capsule()
                    .fill(backgroundColor)
            )
    }

    /// 前景色（文字颜色）
    private var foregroundColor: Color {
        switch style {
        case .neutral:  return RCMTheme.shared.colors.textSecondary
        case .accent:   return RCMTheme.shared.colors.primaryColor
        case .success:  return RCMTheme.shared.colors.successColor
        case .warning:  return RCMTheme.shared.colors.warningColor
        case .danger:   return RCMTheme.shared.colors.dangerColor
        }
    }

    /// 背景色：前景色的 12% 透明度
    private var backgroundColor: Color {
        foregroundColor.opacity(0.12)
    }
}

// MARK: - RCMToggle

public struct RCMToggle: View {
    @Binding private var isOn: Bool
    private let label: String

    public init(isOn: Binding<Bool>, label: String) {
        self._isOn = isOn
        self.label = label
    }

    public var body: some View {
        HStack(spacing: RCMTheme.shared.spacing.sm) {
            Text(label)
                .font(RCMTheme.shared.typography.body)
                .foregroundColor(RCMTheme.shared.colors.textPrimary)
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: RCMTheme.shared.colors.primaryColor))
        }
        .padding(.vertical, RCMTheme.shared.spacing.sm)
    }
}
