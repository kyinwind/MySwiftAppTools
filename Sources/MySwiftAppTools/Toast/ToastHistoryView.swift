//
//  ToastHistoryView.swift
//  MySwiftAppTools
//
//  Toast 消息历史浏览界面。
//

#if os(macOS)
import AppKit
#endif

#if os(iOS)
import UIKit
#endif

import SwiftUI

// MARK: - 背景样式

/// 消息历史界面的背景样式。
///
/// 库视图不该把「有没有底」这件事交给调用方负责：历史界面被裸嵌进别人的容器时，
/// 若自身没有背景就会透出宿主底色（宿主是透明窗口时直接露出桌面）。
/// 所以默认铺一层系统语义背景；调用方要自己接管时，显式选 `.none` 或 `.color(_)`。
public enum ToastHistoryBackground: Sendable, Equatable {

    /// 不铺背景，完全由调用方接管。
    ///
    /// 注意：只有选它，写在 `ToastHistoryView()` **实例外层**的 `.background(...)`
    /// 才会生效 —— 另外两种 case 画在更上层，会把外层背景盖住。
    case none

    /// 系统语义背景（默认）。
    ///
    /// macOS 取 `NSColor.windowBackgroundColor`，iOS 取 `UIColor.systemBackground`，
    /// 随浅色 / 深色模式自动切换，且与窗口、sheet 面板底色一致、无接缝。
    case system

    /// 指定颜色，供调用方注入自家主题色。
    case color(Color)
}

// MARK: - 主视图

/// Toast 消息历史浏览界面。
///
/// 按「最新 → 最旧」显示历史消息，一屏最多 `pageSize` 条（默认 20），
/// 点底部「更多」每次追加一批；每条可单独删除，也可一键清空全部（带二次确认）。
///
/// 两种接入方式：
///
/// ```swift
/// // 1. 嵌入自己的页面或 Sheet
/// .sheet { ToastHistoryView() }
///
/// // 2. macOS 上弹出独立窗口
/// ToastHistoryWindowController.shared.show()
/// ```
@MainActor
public struct ToastHistoryView: View {

    @State private var store: ToastHistoryStore
    /// 观察包内语言：语言切换时整棵子树重建，`packageL` 的结果才会跟着变。
    @State private var languageManager = PackageLanguageManager.shared
    /// 调用方经 `.packageLanguageRefresh(resourceName:)` 注入的语言（子树级，优先级最高）。
    @Environment(\.packageLanguageResourceName) private var injectedResourceName
    /// SwiftUI 环境里的 `Locale`。
    ///
    /// `SwiftHelpCenter` 的 `.SHCAppLanguage(...)` 会往环境注入它并在切语言时重建子树，
    /// 所以读它就能**自动跟随 App 内语言切换，调用方零桥接代码**。
    @Environment(\.locale) private var environmentLocale
    private let pageSize: Int
    private let showsClearAllButton: Bool
    private let onClose: (() -> Void)?
    private let background: ToastHistoryBackground

    /// 白盒单测入口：确认默认参数的解析结果。外部用不到，故不设 `public`。
    internal var resolvedBackground: ToastHistoryBackground { background }

    @State private var visibleCount: Int
    @State private var showsClearConfirm = false

    public init(
        store: ToastHistoryStore = .shared,
        pageSize: Int = 20,
        showsClearAllButton: Bool = true,
        onClose: (() -> Void)? = nil,
        background: ToastHistoryBackground = .system
    ) {
        let size = max(1, pageSize)
        self.store = store
        self.pageSize = size
        self.showsClearAllButton = showsClearAllButton
        self.onClose = onClose
        self.background = background
        self._visibleCount = State(initialValue: size)
    }

    // MARK: 语言

    /// 本视图查表用的 `.lproj` 资源名。
    ///
    /// 优先级（高 → 低）：
    /// 1. **环境键** —— 调用方经 `.packageLanguageRefresh(resourceName:)` 注入，
    ///    或独立窗口 wrapper 注入的全局值；
    /// 2. **环境 `Locale` 派生** —— `SwiftHelpCenter` 的 `.SHCAppLanguage(...)` 注入
    ///    的就是它。这条是「零桥接」的关键：调用方只要用了 SHC 的语言 modifier，
    ///    本视图就自动跟着变，不需要再写任何 `setResourceName` 调用；
    /// 3. 全局值 `PackageLanguageManager.setResourceName(_:)` —— 只在环境推导不出来时兜底
    ///    （包内没有该语言的资源）；
    /// 4. `nil` —— 交给 `Bundle.module` 默认解析（跟随系统）。
    ///
    /// 第 2 条刻意排在全局值**之前**：全局值是「谁最后设谁赢」的弱一致状态，
    /// 一旦调用方漏了某次同步，它会停在旧语言上；而环境 `Locale` 由 SwiftUI
    /// 负责传播，是强一致的。让强一致的那条先赢，界面就不会被过期的全局值钉死。
    private var localizationResourceName: String? {
        if let injectedResourceName { return injectedResourceName }
        if let derived = PackageLocalization.resourceName(for: environmentLocale) { return derived }
        return PackageLocalization.explicitResourceName
    }

    /// 用本视图当前语言查表。视图内的包内文案一律走它，不要直接调 `packageL`。
    private func L(_ key: String, _ args: CVarArg...) -> String {
        packageL(key, resourceName: localizationResourceName, arguments: args)
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            listArea
        }
        // 关键：历史列表**永不参与动画**。
        //
        // 调用方弹 toast 时会用 `withAnimation`（`ToastManager.show` 内部就是），
        // 而历史写入与它发生在同一个 runloop 轮次里，于是新记录的插入会被
        // 卷进那个动画事务。macOS 上 SwiftUI 用「快照」来渲染行的插入过渡，
        // 而把翻转过的 AppKit 视图快照画回未翻转位图会得到**上下镜像**的行
        // （症状：最新的几条消息整行倒着，且行序错乱）。
        // 历史列表是一份日志，插入就该瞬时出现，这里把事务里的动画清掉，
        // 从根上不给它产生中间态的机会。
        .transaction { $0.animation = nil }
        // 语言切换时重建整棵子树：`packageL` 是普通函数、不参与 SwiftUI 依赖追踪，
        // 不换 identity 的话文案会停在旧语言上。
        .id(languageManager.refreshToken)
        .frame(minWidth: 360, minHeight: 280)
        // 自带背景。顺序必须排在 `.frame` **之后**：若排在前面，背景只会覆盖内容
        // 尺寸，被 frame 撑开的那部分仍然是透明的，裸嵌进别人容器照样漏底。
        .background(backgroundStyle)
        .alert(
            L(MySwiftAppToolsL10n.toastHistoryClearConfirmTitle),
            isPresented: $showsClearConfirm
        ) {
            Button(L(MySwiftAppToolsL10n.toastHistoryCancel), role: .cancel) {}
            Button(L(MySwiftAppToolsL10n.toastHistoryDelete), role: .destructive) {
                store.clearAll()
                visibleCount = pageSize
            }
        } message: {
            Text(L(MySwiftAppToolsL10n.toastHistoryClearConfirmMsg, store.records.count))
        }
        .onChange(of: store.records.count) { oldValue, newValue in
            // 新消息插到头部时同步补偿分页计数，避免正在浏览的旧消息被挤出视野。
            guard newValue > oldValue, visibleCount > pageSize else { return }
            visibleCount += newValue - oldValue
        }
    }

    // MARK: 背景

    /// 根视图背景。语义见 `ToastHistoryBackground`。
    private var backgroundStyle: Color {
        switch background {
        case .none:
            return .clear
        case .system:
            #if os(macOS)
            return Color(nsColor: .windowBackgroundColor)
            #else
            return Color(uiColor: .systemBackground)
            #endif
        case .color(let color):
            return color
        }
    }

    // MARK: 顶部工具条

    private var header: some View {
        HStack(spacing: 10) {
            Text(L(MySwiftAppToolsL10n.toastHistoryTitle))
                .font(.headline)

            Text(L(MySwiftAppToolsL10n.toastHistoryCount, store.records.count))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Spacer()

            if showsClearAllButton, !store.records.isEmpty {
                Button(role: .destructive) {
                    showsClearConfirm = true
                } label: {
                    Text(L(MySwiftAppToolsL10n.toastHistoryClearAll))
                }
                .controlSize(.small)
            }

            if let onClose {
                Button {
                    onClose()
                } label: {
                    Text(L(MySwiftAppToolsL10n.toastHistoryClose))
                }
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: 列表

    @ViewBuilder
    private var listArea: some View {
        if store.records.isEmpty {
            emptyState
        } else {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                        ForEach(sections) { section in
                            Section {
                                ForEach(Array(section.records.enumerated()), id: \.element.id) { index, record in
                                    ToastHistoryRow(
                                        record: record,
                                        resourceName: localizationResourceName,
                                        onCopy: { copySilently(record.message) },
                                        onDelete: { store.delete(record) }
                                    )

                                    if index < section.records.count - 1 {
                                        Divider().padding(.leading, 14)
                                    }
                                }
                            } header: {
                                sectionHeader(section.title)
                            }
                        }
                    }
                    .padding(.bottom, 6)
                }

                footer
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        if hasMore {
            Divider()
            Button {
                visibleCount = min(visibleCount + pageSize, store.records.count)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                    Text(L(MySwiftAppToolsL10n.toastHistoryMore, store.records.count - visibleCount))
                }
                .font(.callout)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.vertical, 10)
        } else if store.records.count > pageSize {
            Divider()
            Text(L(MySwiftAppToolsL10n.toastHistoryAllLoaded))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
    }

    private var hasMore: Bool {
        store.records.count > visibleCount
    }

    private var emptyState: some View {
        // 区分两种空态：**功能没开** vs **开了但还没消息**。
        //
        // 不区分的话，App 没开启历史时用户只看到「暂无消息」，会误以为是自己
        // 没产生过消息，而不是功能被关着 —— 后者是可操作的（去设置里打开），
        // 前者只能等。图标也分开：关着用 bell.slash，开着没消息用 tray。
        let disabled = !store.isHistoryEnabled

        return VStack(spacing: 8) {
            Image(systemName: disabled ? "bell.slash" : "tray")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)

            Text(disabled
                 ? L(MySwiftAppToolsL10n.toastHistoryDisabled)
                 : L(MySwiftAppToolsL10n.toastHistoryEmpty))
                .font(.callout)
                .foregroundStyle(.secondary)

            Text(disabled
                 ? L(MySwiftAppToolsL10n.toastHistoryDisabledHint)
                 : L(MySwiftAppToolsL10n.toastHistoryEmptyHint))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(.bar)
    }

    // MARK: 分组

    struct HistorySection: Identifiable {
        let id: Date
        let title: String
        let records: [ToastRecord]
    }

    /// 按自然日分组。只处理当前已加载（visibleCount）的部分。
    var sections: [HistorySection] {
        let visible = Array(store.records.prefix(visibleCount))
        let calendar = Calendar.current

        var order: [Date] = []
        var buckets: [Date: [ToastRecord]] = [:]

        for record in visible {
            let day = calendar.startOfDay(for: record.createdAt)
            if buckets[day] == nil {
                order.append(day)
                buckets[day] = []
            }
            buckets[day]?.append(record)
        }

        return order.map { day in
            HistorySection(
                id: day,
                title: Self.dayTitle(for: day, resourceName: localizationResourceName),
                records: buckets[day] ?? []
            )
        }
    }

    // MARK: 时间展示

    static let hmFormatter = makeFormatter(template: "jmm")
    static let monthDayFormatter = makeFormatter(template: "MMMd jmm")
    static let fullFormatter = makeFormatter(template: "yMMMd jmm")
    static let monthDayWeekFormatter = makeFormatter(template: "MMMdEEEE")
    static let fullDayWeekFormatter = makeFormatter(template: "yMMMdEEEE")

    static func makeFormatter(template: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter
    }

    /// 分组标题：今天 / 昨天 / 9月18日 星期五 / 2025年9月18日 星期四
    ///
    /// `static` 方法拿不到 `self`，所以当前语言由调用方显式传入。
    static func dayTitle(
        for day: Date,
        now: Date = Date(),
        resourceName: String? = nil
    ) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) {
            return packageL(
                MySwiftAppToolsL10n.toastHistoryToday,
                resourceName: resourceName,
                arguments: []
            )
        }
        if calendar.isDateInYesterday(day) {
            return packageL(
                MySwiftAppToolsL10n.toastHistoryYesterday,
                resourceName: resourceName,
                arguments: []
            )
        }
        if calendar.isDate(day, equalTo: now, toGranularity: .year) {
            return monthDayWeekFormatter.string(from: day)
        }
        return fullDayWeekFormatter.string(from: day)
    }

    /// 行内时间：刚刚 / N 分钟前 / 22:41 / 昨天 22:41 / 9月18日 22:41 / 2025年9月18日 22:41
    ///
    /// `static` 方法拿不到 `self`，所以当前语言由调用方显式传入。
    static func timeText(
        for date: Date,
        now: Date = Date(),
        resourceName: String? = nil
    ) -> String {
        let interval = now.timeIntervalSince(date)

        if interval >= 0, interval < 60 {
            return packageL(
                MySwiftAppToolsL10n.toastHistoryJustNow,
                resourceName: resourceName,
                arguments: []
            )
        }
        if interval >= 60, interval < 3600 {
            let minutes = Int(interval / 60)
            return packageL(
                MySwiftAppToolsL10n.toastHistoryMinutesAgo,
                resourceName: resourceName,
                arguments: [minutes]
            )
        }

        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return hmFormatter.string(from: date)
        }
        if calendar.isDateInYesterday(date) {
            return packageL(
                MySwiftAppToolsL10n.toastHistoryYesterday,
                resourceName: resourceName,
                arguments: []
            ) + " " + hmFormatter.string(from: date)
        }
        if calendar.isDate(date, equalTo: now, toGranularity: .year) {
            return monthDayFormatter.string(from: date)
        }
        return fullFormatter.string(from: date)
    }

    /// 精确时间，用于悬停提示。
    static func absoluteTimeText(for date: Date) -> String {
        fullFormatter.string(from: date)
    }
}

// MARK: - 行视图

private struct ToastHistoryRow: View {

    let record: ToastRecord
    /// 本视图当前生效的语言（由 `ToastHistoryView` 传入）。
    let resourceName: String?
    let onCopy: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    private var isDeleteVisible: Bool {
        #if os(macOS)
        return isHovering
        #else
        return true
        #endif
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            record.type.icon
                .font(.system(size: 12))
                .frame(width: 16)

            Text(record.message)
                .font(.system(size: 13))
                .lineLimit(3)
                .truncationMode(.tail)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(ToastHistoryView.timeText(for: record.createdAt, resourceName: resourceName))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .fixedSize()

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(isDeleteVisible ? 1 : 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(isHovering ? Color.primary.opacity(0.05) : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering in
            #if os(macOS)
            isHovering = hovering
            #endif
        }
        .contextMenu {
            Button(
                packageL(
                    MySwiftAppToolsL10n.toastHistoryCopy,
                    resourceName: resourceName,
                    arguments: []
                )
            ) {
                onCopy()
            }
            Divider()
            Button(
                packageL(
                    MySwiftAppToolsL10n.toastHistoryDelete,
                    resourceName: resourceName,
                    arguments: []
                ),
                role: .destructive
            ) {
                onDelete()
            }
        }
        .help(ToastHistoryView.absoluteTimeText(for: record.createdAt))
    }
}

// MARK: - 静默复制

/// 复制到剪贴板，但不弹提示。
///
/// 历史界面里的复制动作必须静默：若沿用 `ShowToastSuccess`，
/// 复制本身又会写进一条历史，造成记录污染。
@MainActor
private func copySilently(_ text: String) {
    #if os(macOS)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
    #elseif os(iOS)
    UIPasteboard.general.string = text
    #endif
}

// MARK: - macOS 独立窗口

#if os(macOS)

/// macOS 上的消息历史独立窗口。
///
/// ```swift
/// ToastHistoryWindowController.shared.show()
/// ```
@MainActor
public final class ToastHistoryWindowController {

    public static let shared = ToastHistoryWindowController()

    private var window: NSWindow?

    public init() {}

    public var isVisible: Bool {
        window?.isVisible ?? false
    }

    /// 显示历史窗口。窗口已存在时直接置前，不重复创建。
    ///
    /// - Parameter background: 历史界面的背景样式。仅在窗口**首次创建**时生效；
    ///   窗口已存在时调用只做置前，不重建内容 —— 重建会丢掉滚动位置与分页状态。
    public func show(
        title: String? = nil,
        width: CGFloat = 520,
        height: CGFloat = 620,
        background: ToastHistoryBackground = .system
    ) {
        // 独立窗口不在 App 的视图树里，拿不到环境 `Locale`，
        // 所以窗口标题只能取「全局设置的语言」。
        let resolvedTitle = title ?? packageL(
            MySwiftAppToolsL10n.toastHistoryTitle,
            resourceName: PackageLocalization.explicitResourceName,
            arguments: []
        )

        if let window {
            window.title = resolvedTitle
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = resolvedTitle
        window.isReleasedWhenClosed = false
        // 显式兜底，不吃 NSWindow 的默认值：将来若改 styleMask 或加上
        // `titlebarAppearsTransparent`，默认底就可能丢，那时整个历史界面会直接透出桌面。
        window.isOpaque = true
        window.backgroundColor = .windowBackgroundColor
        window.contentView = NSHostingView(
            rootView: ToastHistoryWindowRoot(background: background)
        )
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()

        self.window = window
    }

    public func close() {
        window?.close()
    }
}

/// 独立窗口的根视图。
///
/// 独立窗口**不在** App 的视图树里，`@Environment(\.locale)` 只会拿到系统值 ——
/// 所以这里把「全局设置的语言」显式注入环境键，并观察 `PackageLanguageManager`：
/// 语言一变整块重建，窗口标题与内部文案一起跟上。
///
/// 嵌入形态不需要它：`ToastHistoryView` 自己会读环境 `Locale`。
private struct ToastHistoryWindowRoot: View {

    let background: ToastHistoryBackground

    @State private var manager = PackageLanguageManager.shared

    var body: some View {
        ToastHistoryView(background: background)
            .environment(
                \.packageLanguageResourceName,
                PackageLocalization.explicitResourceName
            )
            .id(manager.refreshToken)
    }
}

#endif

// MARK: - Preview

#if DEBUG

/// 完整样本：42 条，跨 6 个自然日。
///
/// 首屏 20 条刚好是「今天 9 条 + 昨天 11 条」，停在自然日边界；
/// 点「更多」继续加载前天分组，再点一次加载完 8 天前之后的内容。
#Preview("消息历史 · 完整数据 42 条") {
    ToastHistoryView(store: ToastHistoryPreviewData.makeStore())
        .frame(width: 520, height: 620)
}

/// 少量样本：不足一屏，用于确认底部「更多」按钮不出现。
#Preview("消息历史 · 不足一屏") {
    ToastHistoryView(store: ToastHistoryPreviewData.makeShortStore())
        .frame(width: 520, height: 480)
}

/// 空状态：验证占位图标与引导文案。
#Preview("消息历史 · 空状态") {
    ToastHistoryView(store: ToastHistoryPreviewData.makeEmptyStore())
        .frame(width: 520, height: 400)
}

/// 历史未开启：验证与「暂无消息」的空态区分（bell.slash 图标 + 独立文案）。
#Preview("消息历史 · 历史未开启") {
    ToastHistoryView(store: ToastHistoryPreviewData.makeDisabledStore())
        .frame(width: 520, height: 400)
}

/// 深色模式：行悬浮底色与分组吸顶用的是系统材质，需单独眼检。
#Preview("消息历史 · 深色模式") {
    ToastHistoryView(store: ToastHistoryPreviewData.makeStore())
        .frame(width: 520, height: 620)
        .preferredColorScheme(.dark)
}

// MARK: 背景三态对照
//
// 三个 Preview 底下都垫了橙色块：只有 `.none` 该透出橙色，
// 另外两个必须是实底 —— 这就是「包自己兜住背景」的验收标准。

#Preview("消息历史 · 背景 .system（默认）") {
    ZStack {
        Color.orange
        ToastHistoryView(store: ToastHistoryPreviewData.makeStore())
    }
    .frame(width: 520, height: 620)
}

#Preview("消息历史 · 背景 .color（主题色接管）") {
    ZStack {
        Color.orange
        ToastHistoryView(
            store: ToastHistoryPreviewData.makeStore(),
            background: .color(.blue.opacity(0.15))
        )
    }
    .frame(width: 520, height: 620)
}

#Preview("消息历史 · 背景 .none（应透出橙色）") {
    ZStack {
        Color.orange
        ToastHistoryView(
            store: ToastHistoryPreviewData.makeStore(),
            background: .none
        )
    }
    .frame(width: 520, height: 620)
}

#endif
