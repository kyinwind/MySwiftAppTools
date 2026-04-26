//
//  MyStyle.swift
//  TipsEveryDay
//
//  Created by xuehui yang on 2024/8/13.
//

import Foundation
import SwiftUI
//MARK: swiftui 字体大小
//在 SwiftUI 中，从小到大的字体顺序如下：
//
//    1.    .caption2 - 非常小的辅助文字
//    2.    .caption - 小的辅助文字
//    3.    .footnote - 脚注，稍大于 .caption
//    4.    .callout - 较小的普通文本
//    5.    .subheadline - 副标题，比 body 小
//    6.    .body - 正常文本
//    7.    .headline - 标题，比 body 稍大
//    8.    .title3 - 比 headline 稍大
//    9.    .title2 - 比 title3 更大
//    10.    .title / .title1 - 大标题
//    11.    .largeTitle - 最大的标题
//
//所以完整的顺序是：
//
//.caption2 < .caption < .footnote < .callout < .subheadline < .body < .headline < .title3 < .title2 < .title < .largeTitle

//•    #FFD700：经典的金黄色，非常接近实际黄金的颜色。
//•    #FFC107：一种较亮的金黄色，常用于现代设计。
//•    #FFDF00：略带橙色调的金黄色，显得更加温暖和耀眼。
//•    #E1AD01：较深的金黄色，模拟了金属的厚重感。
//#3183ff 明亮的蓝色
//#48C6EF：一种柔和的水蓝色
//#5DADE2：接近湖面反射阳光时的蓝色

@Observable
public final class ThemeManager {
    var theme: Theme = Theme()
    
    func updateTheme(theme:Theme) {
        self.theme = theme
    }
}

public struct Theme {
    
    //背景颜色
    var myBGColor:Color = Color.myGray ?? Color(.systemGray)
    //正常字体颜色
    var myFontColor:Color = Color(Color.primary)
    
    //banner背景
    var myBannerBGColor:Color = Color.myBlue ?? Color(.systemBlue)
    //banner字体颜色
    var myBannerFontColor:Color = Color.white
    
    //groupbox背景
    var myGroupboxBGColor:Color = Color.myGray ?? Color(.systemBlue)
    //groupbox前景
    var myGroupboxColor:Color = Color.myBlue ?? Color(.systemBlue)
    //按钮背景
    var myBtnBGColor:Color = Color.myBlue ?? Color(.systemBlue)
    //按钮字体颜色
    var myBtnFontColor:Color = Color.white
    //按钮红色，例如停止
    var myBtnRedColor:Color = Color.red
    
    
}

public extension Color {
    //背景颜色
    static let myGray = Color(hex: "#fdfdfd")
    //其他背景色
    //蓝色
    static let myBlue = Color(hex: "#3183ff")
    static let myBlue2 = Color(hex: "#a2d2ff")
    //薄荷绿
    static let myMintGreen = Color(hex: "#A6E3E9")
    //黑灰色，常用于字体颜色
    static let myDarkGray = Color(hex: "#242424")
    //亮橘色
    static let myOrange = Color(hex: "#FF6F3D")
    //#FFD700：经典的金黄色，非常接近实际黄金的颜色。
    //#FFC107：一种较亮的金黄色，常用于现代设计。
    static let myYellow = Color(hex: "#FFC107")
    //#FFDF00：略带橙色调的金黄色，显得更加温暖和耀眼。
    static let myYellow2 = Color(hex: "#FFDF00")
    //#E1AD01：较深的金黄色，模拟了金属的厚重感。
    static let myYellow3 = Color(hex: "#E1AD01")
}

// UIColor 扩展用于从十六进制字符串创建颜色
public extension Color {
    init?(hex: String) {
        let r, g, b, a: Double
        
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb) // 修复此行
        
        switch hexSanitized.count {
        case 3: // RGB (12-bit)
            r = Double((rgb >> 8) & 0xF) / 15.0
            g = Double((rgb >> 4) & 0xF) / 15.0
            b = Double(rgb & 0xF) / 15.0
            a = 1
        case 6: // RGB (24-bit)
            r = Double((rgb >> 16) & 0xFF) / 255.0
            g = Double((rgb >> 8) & 0xFF) / 255.0
            b = Double(rgb & 0xFF) / 255.0
            a = 1
        case 8: // RGBA (32-bit)
            r = Double((rgb >> 24) & 0xFF) / 255.0
            g = Double((rgb >> 16) & 0xFF) / 255.0
            b = Double((rgb >> 8) & 0xFF) / 255.0
            a = Double(rgb & 0xFF) / 255.0
        default:
            return nil
        }
        
        self.init(red: r, green: g, blue: b, opacity: a)
    }
}

//MARK: 自定义的组件

public struct CustomGroupBoxStyle: GroupBoxStyle {
    var themeManager: ThemeManager
    public init(themeManager: ThemeManager) {
        self.themeManager = themeManager
    }
    public func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading) {
            configuration.label
            Divider()
            configuration.content
                .padding()
                .background(themeManager.theme.myBGColor) // 使用自定义背景颜色
        }
        .background(themeManager.theme.myBGColor) // 使用自定义背景颜色
        .cornerRadius(10) // 可选：设置圆角
        //.shadow(radius: 1) // 可选：添加阴影
    }
}

// 自定义 HStack 样式
public struct CustomHStackStyle: View {
    @Environment(ThemeManager.self) var themeManager: ThemeManager
    let content: () -> AnyView
    
    public var body: some View {
        HStack(alignment: .center) {
            content() // 这里放置要展示的内容
        }
        .padding()
        .background(themeManager.theme.myBannerBGColor) // 使用自定义背景颜色
        .opacity(0.8)
        .cornerRadius(10)
        .shadow(radius: 10) // 添加阴影效果
        //.shadow(radius: 1) // 可选：添加阴影
    }
}

// 自定义 MyHStack 组件，类似于自定义 GroupBox
public struct MyHStack<Content: View>: View {
    let content: Content
    
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    public var body: some View {
        CustomHStackStyle {
            AnyView(content) // 将传递的内容转换为 AnyView
        }
    }
}

//MARK: 所有按钮样式
public struct CustomButtonStyle: ButtonStyle {
    var isEnabled: Bool?
    var themeManager: ThemeManager
    public init(themeManager: ThemeManager) {
        self.themeManager = themeManager
    }
    public init(isEnabled:Bool, themeManager: ThemeManager) {
        self.isEnabled = isEnabled
        self.themeManager = themeManager
    }
    public func makeBody(configuration: Configuration) -> some View {
        if isEnabled != nil {
            configuration.label
                .font(.headline)
                .padding(10)
                .padding(.horizontal,20)
                .background(isEnabled! ? themeManager.theme.myBtnBGColor : .gray)
                .foregroundColor(.white)
                .cornerRadius(10)
                .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
                .animation(.easeInOut(duration: 0.2),value: configuration.isPressed)
        }
        else{
            configuration.label
                .font(.headline)
                .padding(10)
                .padding(.horizontal,20)
                .background(themeManager.theme.myBtnBGColor)
                .foregroundColor(.white)
                .cornerRadius(10)
                .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
                .animation(.easeInOut(duration: 0.2),value: configuration.isPressed)
        }
        
    }
    
}

//MARK: 自定义的 ImageModifier，用于将图像大小设置为两倍
public struct DoubleSizeImageModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .scaledToFit()                // 保持图像比例
            .frame(width: 50, height: 50) // 设置两倍的宽高 (假设原始大小是 20x20)
            .shadow(radius: 10) // 添加阴影效果
    }
}

//MARK: 扩展 View，创建一个便于调用的修饰符
public extension Image {
    func doubleSizedImage() -> some View {
        self.resizable()               // 在 Image 上调用 resizable()，允许调整大小
            .modifier(DoubleSizeImageModifier()) // 应用自定义的 ViewModifier
    }
}

//MARK: 用于设置标准字体

//普通文本
public struct StandardFontModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .font(.headline)
            .fontWeight(.bold) // 加粗
    }
}

//MARK: 扩展 View，创建一个便于调用的修饰符
public extension Text {
    func setStandardFont() -> some View {
        self.modifier(StandardFontModifier()) // 应用自定义的 ViewModifier
    }
}

//MARK: titil字体
public struct StandardTitleFontModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .font(.title3)
            .fontWeight(.bold) // 加粗
    }
}

//MARK: 扩展 View，创建一个便于调用的修饰符
public extension Text {
    func setStandardTitleFont() -> some View {
        self.modifier(StandardTitleFontModifier()) // 应用自定义的 ViewModifier
    }
}

public enum VideoHeroTheme {
    public static let groupTitleFont: Font = .title3.weight(.bold)
    public static let groupSubtitleFont: Font = .callout
    public static let actionButtonFont: Font = .callout.weight(.semibold)
    public static let actionButtonCornerRadius: CGFloat = 14
    public static let actionButtonVerticalPadding: CGFloat = 12
    public static let actionButtonHorizontalPadding: CGFloat = 14
    public static let actionButtonTint: Color = .orange
    public static let actionButtonForeground: Color = .white
}

public struct VideoHeroPrimaryButtonStyle: ButtonStyle {
    var tint: Color = VideoHeroTheme.actionButtonTint
    var isDisabled: Bool = false

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(VideoHeroTheme.actionButtonFont)
            .foregroundStyle(VideoHeroTheme.actionButtonForeground.opacity(isDisabled ? 0.72 : 1))
            .padding(.vertical, VideoHeroTheme.actionButtonVerticalPadding)
            .padding(.horizontal, VideoHeroTheme.actionButtonHorizontalPadding)
            // Primary buttons should size to their content unless a caller explicitly frames them.
            .fixedSize(horizontal: true, vertical: false)
            .background(
                RoundedRectangle(cornerRadius: VideoHeroTheme.actionButtonCornerRadius, style: .continuous)
                    .fill(isDisabled ? Color.gray.opacity(0.55) : tint.opacity(configuration.isPressed ? 0.86 : 1))
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeInOut(duration: 0.14), value: configuration.isPressed)
    }
}

public struct VideoHeroGroupTitleModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .font(VideoHeroTheme.groupTitleFont)
            .foregroundStyle(.primary)
    }
}

public extension View {
    func videoHeroGroupTitle() -> some View {
        modifier(VideoHeroGroupTitleModifier())
    }
}

//MARK: 一个带提示符的文本编辑器
public struct PlaceholderTextEditor: View {
    @Binding var text: String
    let placeholder: String
    
    public var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.4))
                )
            
            if text.isEmpty {
                Text(placeholder)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
            }
        }
    }
}

//MARK: 自定义的label
public struct LabeledField<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    public init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)
            content
        }
    }
}

//MARK: 将一个Double转为字符串，保留N位小数点
public extension Double {
    var oneDecimal: String {
        String(format: "%.1f", self)
    }
    var twoDecimal: String {
        String(format: "%.2f", self)
    }
}
//MARK: 一个支持只读的文本显示组件
public struct ReadOnlyTextView: NSViewRepresentable {
    
    // MARK: - Inputs
    @Binding var text: String
    var isEditable: Bool = false
    var isSelectable: Bool = true
    var font: NSFont = .systemFont(ofSize: 14)
    
    // MARK: - 协调器：用于监听 NSTextView 的文本变化，实现双向绑定
    public class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ReadOnlyTextView
        
        init(parent: ReadOnlyTextView) {
            self.parent = parent
        }
        
        // 监听文本变化，同步到 SwiftUI 的 Binding
        public func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            // 避免循环更新：只有文本真的变化时才同步
            if textView.string != parent.text {
                parent.text = textView.string
            }
        }
    }
    
    // MARK: - Make
    public func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    public func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        
        // 🔹 行为控制
        textView.isEditable = isEditable
        textView.isSelectable = isSelectable
        
        // 🔹 外观
        textView.drawsBackground = false
        textView.font = font
        //textView.textContainerInset = NSSize(width: 8, height: 8)
        
        // 🔹 尺寸 & 滚动
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        
        // 🔹 关键：设置代理，监听文本变化
        textView.delegate = context.coordinator
        
        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder
        
        textView.string = text
        
        return scrollView
    }
    
    // MARK: - Update
    public func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        
        // 行为更新（允许运行时切换）
        if textView.isEditable != isEditable {
            textView.isEditable = isEditable
        }
        if textView.isSelectable != isSelectable {
            textView.isSelectable = isSelectable
        }
        
        // 文本更新（避免重复 set 导致滚动跳动）
        if textView.string != text {
            let selectedRange = textView.selectedRange()
            textView.string = text
            textView.setSelectedRange(selectedRange)
        }
        
        // 字体更新
        if textView.font != font {
            textView.font = font
        }
    }
}

//为了解决TextEditor文字上面被截的问题，特意写了CustomTextView
public struct CustomTextView: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String = "请输入..."
    var maxLength: Int? = nil
    
    public func makeNSView(context: Context) -> NSScrollView {
        
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        
        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.font = NSFont.systemFont(ofSize: 16)
        textView.backgroundColor = NSColor.clear
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.bounds.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = true
        
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.textContainer?.lineFragmentPadding = 0
        
        scrollView.documentView = textView
        
        // placeholder
        let placeholderLabel = NSTextField(labelWithString: placeholder)
        placeholderLabel.textColor = NSColor.placeholderTextColor
        placeholderLabel.font = textView.font
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.isHidden = !text.isEmpty
        
        textView.addSubview(placeholderLabel)
        
        NSLayoutConstraint.activate([
            placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 6),
            placeholderLabel.topAnchor.constraint(equalTo: textView.topAnchor, constant: 6)
        ])
        
        context.coordinator.textView = textView
        context.coordinator.placeholderLabel = placeholderLabel
        
        return scrollView
    }
    
    public func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        
        if textView.string != text {
            textView.string = text
        }
        
        context.coordinator.updatePlaceholder()
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public class Coordinator: NSObject, NSTextViewDelegate {
        
        var parent: CustomTextView
        weak var textView: NSTextView?
        weak var placeholderLabel: NSTextField?
        
        init(_ parent: CustomTextView) {
            self.parent = parent
        }
        
        // 限制最大长度
        public func textView(
            _ textView: NSTextView,
            shouldChangeTextIn affectedCharRange: NSRange,
            replacementString: String?
        ) -> Bool {
            
            guard let maxLength = parent.maxLength else {
                return true
            }
            
            let currentText = textView.string
            let replacement = replacementString ?? ""
            
            guard let range = Range(affectedCharRange, in: currentText) else {
                return true
            }
            
            let newText = currentText.replacingCharacters(in: range, with: replacement)
            
            return newText.count <= maxLength
        }
        
        public func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            
            parent.text = textView.string
            updatePlaceholder()
        }
        
        @MainActor
        func updatePlaceholder() {
            placeholderLabel?.isHidden = !(textView?.string.isEmpty ?? true)
        }
    }
}

//MARK: esc键快捷关闭窗口
//使用方法
//.modifier(EscCloseModifier())
public struct EscCloseModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    let enabled: Bool
    
    public func body(content: Content) -> some View {
        content.background(
            Group {
                if enabled {
                    Button("") {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                    .opacity(0)
                }
            }
        )
    }
}

//MARK: 自定义交通灯按钮组件
public struct ToobarStatusLight: View {
    @Environment(\.isEnabled) private var isEnabled
    //isOn如果为空，则代表不需要绿灯效果，正常显示就行
    let isOn: Bool?
    let systemImage: String
    let title: String
    let accentColor: Color?

    public init(
        isOn: Bool? = nil,
        systemImage: String,
        title: String,
        accentColor: Color? = nil
    ) {
        self.isOn = isOn
        self.systemImage = systemImage
        self.title = title
        self.accentColor = accentColor
    }
    
    public var body: some View {
        let color: Color = {
            if let accentColor {
                return accentColor
            }
            guard let isOn else { return .primary }
            return isOn ? .green : .gray
        }()
        let colorText:Color = {
            if accentColor != nil {
                return .primary
            }
            guard let isOn else { return .primary }
            return isOn ? .primary : .secondary
        }()
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(color)
                .imageScale(.large)
            
            Text(title)
            //.font(.caption)
                .foregroundStyle(colorText)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 120, alignment: .leading)
        }
        .foregroundStyle(isEnabled ? .primary : .secondary)
        .opacity(isEnabled ? 1.0 : 0.4)
    }
}

//MARK: 设置页面的卡片组件MySettingsCard
private struct MySettingsCardBorderKey: EnvironmentKey {
    static let defaultValue: Bool = true   // 默认显示
}

public extension EnvironmentValues {
    var mySettingsCardShowsBorder: Bool {
        get { self[MySettingsCardBorderKey.self] }
        set { self[MySettingsCardBorderKey.self] = newValue }
    }
}
public extension View {
    func showBorder(_ show: Bool) -> some View {
        environment(\.mySettingsCardShowsBorder, show)
    }
}

public struct MySettingsCard<Content: View>: View {
    
    private let title: LocalizedStringKey
    private let subtitle: LocalizedStringKey?
    private let content: Content
    @Environment(\.mySettingsCardShowsBorder)
    private var showsBorder
    public init(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            headerView
            
            Divider()
            
            content
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.windowBackgroundColor))
            
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.15))
                .opacity(showsBorder ? 1 : 0)
        )
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.largeTitle)
                .fontWeight(.semibold)
            
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - 按钮组组件 ActionBarAlignment
public enum ActionBarAlignment: Sendable {
    case leading
    case center
    case trailing
    
    var swiftUIAlignment: Alignment {
        switch self {
        case .leading:  return .leading
        case .center:   return .center
        case .trailing: return .trailing
        }
    }
}

public enum ActionBarLayoutStyle: Equatable, Sendable {
    /// Preserve the original behavior: single row when there is room, compact control group when not.
    case automatic
    /// Always render actions in one horizontal row.
    case horizontal
    /// Keep each button at its normal height and wrap onto additional rows when needed.
    case wrapping
    /// Always render actions through the compact control group.
    case compact
}

// MARK: - Shortcut Model（⭐️核心）
public struct ActionShortcut: Equatable,  Sendable {
    public let key: KeyEquivalent
    public let modifiers: EventModifiers

    public init(key: KeyEquivalent, modifiers: EventModifiers) {
        self.key = key
        self.modifiers = modifiers
    }

    public static let commandA = ActionShortcut(key: "a", modifiers: [.command])
    public static let commandB = ActionShortcut(key: "b", modifiers: [.command])
    public static let commandC = ActionShortcut(key: "c", modifiers: [.command])
    public static let commandD = ActionShortcut(key: "d", modifiers: [.command])
    public static let commandE = ActionShortcut(key: "e", modifiers: [.command])
    public static let commandF = ActionShortcut(key: "f", modifiers: [.command])
    public static let commandG = ActionShortcut(key: "g", modifiers: [.command])
    public static let commandH = ActionShortcut(key: "h", modifiers: [.command])
    public static let commandI = ActionShortcut(key: "i", modifiers: [.command])
    public static let commandJ = ActionShortcut(key: "j", modifiers: [.command])
    public static let commandK = ActionShortcut(key: "k", modifiers: [.command])
    public static let commandL = ActionShortcut(key: "l", modifiers: [.command])
    public static let commandM = ActionShortcut(key: "m", modifiers: [.command])
    public static let commandN = ActionShortcut(key: "n", modifiers: [.command])
    public static let commandO = ActionShortcut(key: "o", modifiers: [.command])
    public static let commandP = ActionShortcut(key: "p", modifiers: [.command])
    public static let commandQ = ActionShortcut(key: "q", modifiers: [.command])
    public static let commandR = ActionShortcut(key: "r", modifiers: [.command])
    public static let commandS = ActionShortcut(key: "s", modifiers: [.command])
    public static let commandT = ActionShortcut(key: "t", modifiers: [.command])
    public static let commandU = ActionShortcut(key: "u", modifiers: [.command])
    public static let commandV = ActionShortcut(key: "v", modifiers: [.command])
    public static let commandW = ActionShortcut(key: "w", modifiers: [.command])
    public static let commandX = ActionShortcut(key: "x", modifiers: [.command])
    public static let commandY = ActionShortcut(key: "y", modifiers: [.command])
    public static let commandZ = ActionShortcut(key: "z", modifiers: [.command])
    public static let delete = ActionShortcut(key: .delete, modifiers: [])
    public static let escape = ActionShortcut(key: .escape, modifiers: [])
    public static let commandNothing = ActionShortcut(key: " ", modifiers: [])

    public var displayString: String {
        var result = ""

        if modifiers.contains(.command) { result += "⌘" }
        if modifiers.contains(.shift) { result += "⇧" }
        if modifiers.contains(.option) { result += "⌥" }
        if modifiers.contains(.control) { result += "⌃" }

        switch key {
        case .delete:
            result += "⌫"
        case .escape:
            result += "Esc"
        default:
            result += String(key.character).uppercased()
        }

        return result
    }
}

// MARK: - ActionItem

public enum ActionItem: Identifiable {

    case add(
        enabled: Bool = true,
        shortcut: ActionShortcut? = nil,
        action: () -> Void
    )

    case edit(
        enabled: Bool = true,
        shortcut: ActionShortcut? = nil,
        action: () -> Void
    )

    case delete(
        enabled: Bool = true,
        action: () -> Void
    )

    case save(
        enabled: Bool = true,
        shortcut: ActionShortcut? = nil,
        action: () -> Void
    )

    case exit(
        enabled: Bool = true,
        shortcut: ActionShortcut? = nil,
        action: () -> Void
    )

    case menu(
        title: String,
        systemImage: String,
        enabled: Bool = true,
        content: () -> AnyView
    )

    /// Custom actions can show either a text title or fully custom content.
    /// Per-item displayStyle wins over the ActionBar-level buttonDisplayStyle.
    case custom(
        title: String? = nil,
        content: (() -> AnyView)? = nil,
        systemImage: String,
        displayStyle: ActionBarButtonDisplayStyle? = nil,
        enabled: Bool = true,
        shortcut: ActionShortcut? = nil,
        action: () -> Void
    )

    public var id: String {
        switch self {
        case .add: return "add"
        case .edit: return "edit"
        case .delete: return "delete"
        case .save: return "save"
        case .exit: return "exit"
        case .menu(let title, _, _, _):
            return "menu_\(title)"
        case .custom(let title, _, let image, _, _, _, _):
            return "custom_\(title ?? image)"
        }
    }
}

private enum LayoutMode {
    case regular
    case compact
}

private struct ActionBarFlowLayout: Layout {
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat
    let alignment: ActionBarAlignment

    private struct Row {
        var indices: [Int] = []
        var sizes: [CGSize] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = max(proposal.width ?? .greatestFiniteMagnitude, 1)
        let rows = makeRows(for: subviews, maxWidth: maxWidth)
        let contentWidth = rows.map(\.width).max() ?? 0
        let contentHeight = rows.reduce(CGFloat.zero) { total, row in
            total + row.height
        } + verticalSpacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(
            width: proposal.width ?? contentWidth,
            height: contentHeight
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let rows = makeRows(for: subviews, maxWidth: max(bounds.width, 1))
        var y = bounds.minY

        for row in rows {
            let startX = rowStartX(rowWidth: row.width, bounds: bounds)
            var x = startX

            for (offset, index) in row.indices.enumerated() {
                let size = row.sizes[offset]
                let point = CGPoint(
                    x: x,
                    y: y + (row.height - size.height) / 2
                )
                subviews[index].place(
                    at: point,
                    anchor: .topLeading,
                    proposal: ProposedViewSize(size)
                )
                x += size.width + horizontalSpacing
            }

            y += row.height + verticalSpacing
        }
    }

    private func makeRows(for subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let nextWidth = current.indices.isEmpty
                ? size.width
                : current.width + horizontalSpacing + size.width

            if !current.indices.isEmpty && nextWidth > maxWidth {
                rows.append(current)
                current = Row()
            }

            current.indices.append(index)
            current.sizes.append(size)
            current.width = current.width == 0 ? size.width : current.width + horizontalSpacing + size.width
            current.height = max(current.height, size.height)
        }

        if !current.indices.isEmpty {
            rows.append(current)
        }
        return rows
    }

    private func rowStartX(rowWidth: CGFloat, bounds: CGRect) -> CGFloat {
        switch alignment {
        case .leading:
            return bounds.minX
        case .center:
            return bounds.minX + max((bounds.width - rowWidth) / 2, 0)
        case .trailing:
            return bounds.maxX - min(rowWidth, bounds.width)
        }
    }
}

/// Optional visual treatment for ActionBar buttons. Keeping this separate from
/// `ActionItem` lets callers opt into branded buttons without changing defaults.
public struct ActionBarButtonDisplayStyle:  Sendable {
    public let backgroundColor: Color
    public let foregroundColor: Color
    public let cornerRadius: CGFloat

    public init(
        backgroundColor: Color,
        foregroundColor: Color,
        cornerRadius: CGFloat = RCMRadius.md
    ) {
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.cornerRadius = cornerRadius
    }

    /// App primary action style: orange background with white text.
    public static let primary = ActionBarButtonDisplayStyle(
        backgroundColor: .orange,
        foregroundColor: .white
    )
}

private struct ActionBarDisplayButtonStyle: ButtonStyle {
    let displayStyle: ActionBarButtonDisplayStyle
    let isEnabled: Bool

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(RCMTypography.bodyStrong)
            .foregroundStyle(displayStyle.foregroundColor.opacity(isEnabled ? 1 : 0.72))
            .frame(height: RCMControlSize.buttonHeight)
            .padding(.horizontal, RCMSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: displayStyle.cornerRadius, style: .continuous)
                    .fill(displayStyle.backgroundColor.opacity(backgroundOpacity(isPressed: configuration.isPressed)))
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private func backgroundOpacity(isPressed: Bool) -> Double {
        guard isEnabled else { return 0.55 }
        return isPressed ? 0.86 : 1.0
    }
}

// MARK: - ActionBar

public struct ActionBar: View {

    let items: [ActionItem]
    var alignment: ActionBarAlignment = .leading
    var layoutStyle: ActionBarLayoutStyle = .automatic
    var buttonDisplayStyle: ActionBarButtonDisplayStyle?

    @State private var availableWidth: CGFloat = 0
    @State private var regularWidth: CGFloat = 0

    public init(
        items: [ActionItem],
        alignment: ActionBarAlignment = .leading,
        layoutStyle: ActionBarLayoutStyle = .automatic,
        buttonDisplayStyle: ActionBarButtonDisplayStyle? = nil
    ) {
        self.items = items
        self.alignment = alignment
        self.layoutStyle = layoutStyle
        self.buttonDisplayStyle = buttonDisplayStyle
    }

    private var layoutMode: LayoutMode {
        availableWidth >= regularWidth ? .regular : .compact
    }

    public var body: some View {
        if layoutStyle == .wrapping {
            baseContent
                .frame(maxWidth: .infinity)
        } else {
            baseContent
                .frame(height: barHeight)
                .frame(maxWidth: .infinity)
                .background(widthReader)
                .overlay(measurementLayer)
        }
    }

    private var baseContent: some View {
        ZStack(alignment: alignment.swiftUIAlignment) {
            content
        }
    }

    private var widthReader: some View {
        GeometryReader { geo in
            Color.clear
                .onAppear { availableWidth = geo.size.width }
                .onChange(of: geo.size.width) { _, v in
                    availableWidth = v
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch layoutStyle {
        case .automatic:
#if os(macOS)
            switch layoutMode {
            case .regular:
                regularBar
            case .compact:
                compactBar
            }
#else
            regularBar
#endif
        case .horizontal:
            regularBar
        case .wrapping:
            wrappingBar
        case .compact:
            compactBar
        }
    }

    private var regularBar: some View {
        HStack {
            if alignment != .leading { Spacer() }

            HStack(spacing: 8) {
                ForEach(items) { item in
                    buildButton(for: item)
                }
            }
            .fixedSize()

            if alignment != .trailing { Spacer() }
        }
    }

    private var compactBar: some View {
        HStack {
            if alignment != .leading { Spacer() }

            ControlGroup {
                ForEach(items) { item in
                    buildButton(for: item)
                }
            }

            if alignment != .trailing { Spacer() }
        }
    }

    private var wrappingBar: some View {
        ActionBarFlowLayout(
            horizontalSpacing: 8,
            verticalSpacing: 8,
            alignment: alignment
        ) {
            ForEach(items) { item in
                buildButton(for: item)
            }
        }
    }

    private var measurementLayer: some View {
        Group {
            if layoutStyle == .automatic {
                regularBar
                    .opacity(0)
                    .overlay(
                        GeometryReader { geo in
                            Color.clear
                                .onAppear {
                                    regularWidth = geo.size.width
                                }
                                .onChange(of: geo.size.width) { _, v in
                                    regularWidth = v
                                }
                        }
                    )
            }
        }
    }

    @ViewBuilder
    private func buildButton(for item: ActionItem) -> some View {
        switch item {
        case let .add(enabled, shortcut, action):
            applyShortcut(shortcut,
                to: styledButton(enabled: enabled, displayStyle: nil, view: Button(action: action) {
                    actionLabel(title: "新增", systemImage: "plus", shortcut: shortcut)
                }
                .disabled(!enabled)
                .help("新增")
                )
            )

        case let .edit(enabled, shortcut, action):
            applyShortcut(shortcut,
                to: styledButton(enabled: enabled, displayStyle: nil, view: Button(action: action) {
                    actionLabel(title: "修改", systemImage: "pencil", shortcut: shortcut)
                }
                .disabled(!enabled)
                .help("修改")
                )
            )

        case let .delete(enabled, action):
            styledButton(enabled: enabled, displayStyle: nil, view: Button(role: .destructive, action: action) {
                actionLabel(title: "删除", systemImage: "trash", shortcut: nil)
            }
            .disabled(!enabled)
            .help("删除")
            )

        case let .save(enabled, shortcut, action):
            applyShortcut(shortcut,
                to: styledButton(enabled: enabled, displayStyle: nil, view: Button(action: action) {
                    actionLabel(title: "保存", systemImage: "square.and.arrow.down", shortcut: shortcut)
                }
                .disabled(!enabled)
                .help("保存")
                )
            )

        case let .exit(enabled, shortcut, action):
            applyShortcut(shortcut,
                to: styledButton(enabled: enabled, displayStyle: nil, view: Button(role: .destructive, action: action) {
                    actionLabel(title: "退出", systemImage: "xmark.circle", shortcut: shortcut)
                }
                .disabled(!enabled)
                .help("退出")
                )
            )

        case let .custom(title, content, image, displayStyle, enabled, shortcut, action):
            let helpTitle = title ?? ""
            applyShortcut(shortcut,
                to: styledButton(enabled: enabled, displayStyle: displayStyle, view: Button(action: action) {
                    customLabel(title: title, content: content, systemImage: image, shortcut: shortcut)
                }
                .disabled(!enabled)
                .help(helpTitle)
                )
            )

        case let .menu(title, image, enabled, content):
            styledButton(enabled: enabled, displayStyle: nil, view: Menu {
                content()
            } label: {
                actionLabel(title: title, systemImage: image, shortcut: nil)
            }
            .disabled(!enabled)
            .help(title)
            )
        }
    }

    @ViewBuilder
    private func actionLabel(title: String, systemImage: String, shortcut: ActionShortcut?) -> some View {
        if let shortcut, shortcut.displayString != " " {
            HStack(spacing: 4) {
                if !systemImage.isEmpty {
                    Image(systemName: systemImage)
                }
                Text(title)
                shortcutLabel(shortcut)
            }
        } else if systemImage.isEmpty {
            Text(title)
        } else {
            Label(title, systemImage: systemImage)
        }
    }

    @ViewBuilder
    private func customLabel(
        title: String?,
        content: (() -> AnyView)?,
        systemImage: String,
        shortcut: ActionShortcut?
    ) -> some View {
        if let content {
            HStack(spacing: 4) {
                if !systemImage.isEmpty {
                    Image(systemName: systemImage)
                }
                content()
                if let shortcut, shortcut.displayString != " " {
                    shortcutLabel(shortcut)
                }
            }
        } else if let title {
            actionLabel(title: title, systemImage: systemImage, shortcut: shortcut)
        } else if !systemImage.isEmpty {
            Image(systemName: systemImage)
        } else {
            EmptyView()
        }
    }

    private func shortcutLabel(_ shortcut: ActionShortcut) -> some View {
        Text("(\(shortcut.displayString))")
            .font(.system(size: 10, weight: .regular))
            .foregroundColor(.secondary)
            .opacity(0.7)
    }

    @ViewBuilder
    private func styledButton(
        enabled: Bool,
        displayStyle: ActionBarButtonDisplayStyle?,
        view: some View
    ) -> some View {
        if let resolvedStyle = displayStyle ?? buttonDisplayStyle {
            view.buttonStyle(ActionBarDisplayButtonStyle(
                displayStyle: resolvedStyle,
                isEnabled: enabled
            ))
        } else {
            view
        }
    }

    @ViewBuilder
    private func applyShortcut(
        _ shortcut: ActionShortcut?,
        to view: some View
    ) -> some View {
        if let shortcut, shortcut.displayString != " " {
            view.keyboardShortcut(shortcut.key, modifiers: shortcut.modifiers)
        } else {
            view
        }
    }

    private var barHeight: CGFloat {
#if os(macOS)
        36
#else
        44
#endif
    }
}

//MARK: 从Bundle读取版本，app名称，用于显示
public struct AppInfo {
    
    public static let name: String = {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
        ?? "App"
    }()
    
    public static let version: String = {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }()
    
    public static let build: String = {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
    }()
    
    public static let fullVersion: String = {
        build.isEmpty ? version : "\(version) (\(build))"
    }()
    public static var icon: NSImage {
        NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        Spacer()
        Text("拖动窗口宽度试试")
            .font(.headline)
        
        ActionBar(items: [
            .add { print("Add") },
            .edit(enabled: false) { },
            .delete { },
            .custom(
                title: "导出",
                systemImage: "square.and.arrow.up"
            ) { }
        ])
        .padding()
        
        Spacer()
    }
    .frame(minWidth: 360, minHeight: 200)
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        Spacer()
        Text("拖动窗口宽度试试")
            .font(.headline)
        
        ActionBar(items: [
            .add { print("Add") },
            .edit(enabled: false) { },
            .delete { },
            .custom(
                title: "导出",
                systemImage: "square.and.arrow.up"
            ) { }
        ])
        .padding()
        
        Spacer()
    }
    .frame(minWidth: 360, minHeight: 200)
}

// MARK: - 示例用法（可删）

#Preview {
    VStack(spacing: 20) {
        ActionBar(items: [
            .add {
                print("Add")
            },
            .edit(enabled: false) {
                print("Edit")
            },
            .delete {
                print("Delete")
            },
            .save{
                print("save")
            },
            .exit{
                print("exit")
            },
            .custom(
                title: "导出",
                systemImage: "square.and.arrow.up"
            ) {
                print("Export")
            }
        ])
    }
    .padding()
}
