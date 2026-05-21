import Foundation
import SwiftUI
#if os(macOS)
import AppKit
#endif

// MARK: - Help Center Models

public enum RCMHelpVideoPreferredPlatform: Sendable {
    case automatic
    case bilibili
    case youtube
}

public struct RCMHelpVideoLinks: Codable, Hashable, Sendable {
    public var bilibiliURL: URL?
    public var youtubeURL: URL?

    public init(
        bilibiliURL: URL? = nil,
        youtubeURL: URL? = nil
    ) {
        self.bilibiliURL = bilibiliURL
        self.youtubeURL = youtubeURL
    }

    public var hasAnyLink: Bool {
        bilibiliURL != nil || youtubeURL != nil
    }

    public func preferredURL(_ preferredPlatform: RCMHelpVideoPreferredPlatform = .automatic) -> URL? {
        switch preferredPlatform {
        case .automatic:
            if Locale.current.language.languageCode?.identifier == "zh" {
                return bilibiliURL ?? youtubeURL
            }
            return youtubeURL ?? bilibiliURL
        case .bilibili:
            return bilibiliURL ?? youtubeURL
        case .youtube:
            return youtubeURL ?? bilibiliURL
        }
    }
}

public enum RCMHelpQuickLinkAction: Hashable, Sendable {
    case url(URL)
    case feedback
    case appStoreReview
    case support
}

public struct RCMHelpQuickLinkItem: Identifiable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var subtitle: String?
    public var systemImage: String
    public var action: RCMHelpQuickLinkAction

    public init(
        id: String? = nil,
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        url: URL
    ) {
        self.id = id ?? title
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.action = .url(url)
    }

    public init(
        id: String? = nil,
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        action: RCMHelpQuickLinkAction
    ) {
        self.id = id ?? title
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.action = action
    }

    public static func feedback(
        title: String = packageL(MySwiftAppToolsL10n.helpCenterFeedback),
        subtitle: String? = nil
    ) -> Self {
        Self(title: title, subtitle: subtitle, systemImage: "bubble.left.and.text.bubble.right", action: .feedback)
    }

    public static func appStoreReview(
        title: String = packageL(MySwiftAppToolsL10n.helpCenterRate),
        subtitle: String? = nil
    ) -> Self {
        Self(title: title, subtitle: subtitle, systemImage: "star", action: .appStoreReview)
    }

    public static func support(
        title: String = packageL(MySwiftAppToolsL10n.helpCenterOpenSupport),
        subtitle: String? = nil
    ) -> Self {
        Self(title: title, subtitle: subtitle, systemImage: "safari", action: .support)
    }
}

public struct RCMHelpFAQItem: Identifiable, Hashable, Sendable {
    public var id: String
    public var question: String
    public var answer: String

    public init(id: String? = nil, question: String, answer: String) {
        self.id = id ?? question
        self.question = question
        self.answer = answer
    }
}

public struct RCMVersionHistoryItem: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var versionName: String
    public var publishedAt: Date
    public var changes: String
    public var videoTitle: String?
    public var videoLinks: RCMHelpVideoLinks

    public init(
        id: String? = nil,
        versionName: String,
        publishedAt: Date,
        changes: String,
        videoTitle: String? = nil,
        bilibiliURL: URL? = nil,
        youtubeURL: URL? = nil
    ) {
        self.id = id ?? Self.makeID(versionName: versionName, publishedAt: publishedAt)
        self.versionName = versionName
        self.publishedAt = publishedAt
        self.changes = changes
        self.videoTitle = videoTitle
        self.videoLinks = RCMHelpVideoLinks(
            bilibiliURL: bilibiliURL,
            youtubeURL: youtubeURL
        )
    }

    public init?(
        id: String? = nil,
        versionName: String,
        publishedAtString: String,
        dateFormat: String = "yyyy-MM-dd",
        changes: String,
        videoTitle: String? = nil,
        bilibiliURL: URL? = nil,
        youtubeURL: URL? = nil
    ) {
        guard let publishedAt = Self.date(from: publishedAtString, dateFormat: dateFormat) else {
            return nil
        }
        self.init(
            id: id,
            versionName: versionName,
            publishedAt: publishedAt,
            changes: changes,
            videoTitle: videoTitle,
            bilibiliURL: bilibiliURL,
            youtubeURL: youtubeURL
        )
    }

    public var hasVideoLinks: Bool {
        videoLinks.hasAnyLink
    }

    public func preferredVideoURL(_ preferredPlatform: RCMHelpVideoPreferredPlatform = .automatic) -> URL? {
        videoLinks.preferredURL(preferredPlatform)
    }

    private static func makeID(versionName: String, publishedAt: Date) -> String {
        "\(versionName)-\(Int(publishedAt.timeIntervalSince1970))"
    }

    private static func date(from string: String, dateFormat: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = dateFormat
        return formatter.date(from: string)
    }
}

// MARK: - Help Center Manager

@MainActor
@Observable
public final class RCMHelpCenterManager {
    public static let shared = RCMHelpCenterManager()

    public private(set) var items: [RCMVersionHistoryItem] = []
    public private(set) var quickLinks: [RCMHelpQuickLinkItem] = []
    public private(set) var faqItems: [RCMHelpFAQItem] = []
    public private(set) var lastViewedPublishedAt: Date = .distantPast
    public private(set) var supportURL: URL?
    public private(set) var accentColor: Color = RCMTheme.shared.colors.accent
    public private(set) var unreadColor: Color = RCMTheme.shared.colors.danger

    private var defaults: UserDefaults = .standard
    private var storageKey = "MySwiftAppTools.RCMHelpCenter.lastViewedPublishedAt"
    private var isConfigured = false

    public init() {}

    public func configure(
        items: [RCMVersionHistoryItem],
        storageKey: String,
        supportURL: URL? = nil,
        quickLinks: [RCMHelpQuickLinkItem] = [],
        faqItems: [RCMHelpFAQItem] = [],
        includeDefaultFeedbackLinks: Bool = true,
        accentColor: Color = RCMTheme.shared.colors.accent,
        unreadColor: Color = RCMTheme.shared.colors.danger,
        defaults: UserDefaults = .standard,
        markExistingItemsAsReadOnFirstConfigure: Bool = true
    ) {
        self.items = items.sorted { $0.publishedAt > $1.publishedAt }
        self.quickLinks = Self.mergedQuickLinks(
            customLinks: quickLinks,
            includeDefaultFeedbackLinks: includeDefaultFeedbackLinks
        )
        self.faqItems = faqItems
        self.storageKey = storageKey
        self.supportURL = supportURL
        self.accentColor = accentColor
        self.unreadColor = unreadColor
        self.defaults = defaults
        self.isConfigured = true

        if let storedDate = defaults.object(forKey: storageKey) as? Date {
            lastViewedPublishedAt = storedDate
            return
        }

        if let storedTimeInterval = defaults.object(forKey: storageKey) as? TimeInterval {
            lastViewedPublishedAt = Date(timeIntervalSince1970: storedTimeInterval)
            return
        }

        if markExistingItemsAsReadOnFirstConfigure, let latestPublishedAt {
            saveLastViewedPublishedAt(latestPublishedAt)
        } else {
            lastViewedPublishedAt = .distantPast
        }
    }

    public var latestPublishedAt: Date? {
        items.map(\.publishedAt).max()
    }

    public var hasUnreadUpdates: Bool {
        items.contains { isUnread($0) }
    }

    public func isUnread(_ item: RCMVersionHistoryItem) -> Bool {
        item.publishedAt > lastViewedPublishedAt
    }

    public func markAsRead(_ item: RCMVersionHistoryItem) {
        guard isConfigured else { return }
        guard item.publishedAt > lastViewedPublishedAt else { return }
        saveLastViewedPublishedAt(item.publishedAt)
    }

    public func markAllAsRead() {
        guard isConfigured, let latestPublishedAt else { return }
        saveLastViewedPublishedAt(latestPublishedAt)
    }

    public func resetReadState() {
        defaults.removeObject(forKey: storageKey)
        lastViewedPublishedAt = .distantPast
    }

    private func saveLastViewedPublishedAt(_ date: Date) {
        lastViewedPublishedAt = date
        defaults.set(date, forKey: storageKey)
    }

    private static func mergedQuickLinks(
        customLinks: [RCMHelpQuickLinkItem],
        includeDefaultFeedbackLinks: Bool
    ) -> [RCMHelpQuickLinkItem] {
        var links = customLinks

        guard includeDefaultFeedbackLinks, FeedbackManager.shared.isConfigured else {
            return links
        }

        if !links.contains(where: { $0.action == .feedback }) {
            links.append(.feedback())
        }

        if !links.contains(where: { $0.action == .appStoreReview }) {
            links.append(.appStoreReview())
        }

        return links
    }
}

// MARK: - Help Center Window

#if os(macOS)
@MainActor
public final class RCMHelpCenterWindowPresenter {
    public static let shared = RCMHelpCenterWindowPresenter()

    private var window: NSWindow?

    public init() {}

    public func show(
        title: String = packageL(MySwiftAppToolsL10n.helpCenterTitle),
        preferredPlatform: RCMHelpVideoPreferredPlatform = .automatic,
        manager: RCMHelpCenterManager = .shared
    ) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let rootView = RCMVersionHistoryListView(
            title: title,
            manager: manager
        )
        .frame(minWidth: 760, minHeight: 560)

        let hostingController = NSHostingController(rootView: rootView)
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        newWindow.title = title
        newWindow.contentViewController = hostingController
        center(newWindow)
        newWindow.isReleasedWhenClosed = false
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        window = newWindow
    }

    private func center(_ window: NSWindow) {
        let targetScreen = NSApp.keyWindow?.screen
            ?? NSApp.mainWindow?.screen
            ?? NSScreen.main

        guard let visibleFrame = targetScreen?.visibleFrame else {
            window.center()
            return
        }

        let windowSize = window.frame.size
        let origin = NSPoint(
            x: visibleFrame.midX - windowSize.width / 2,
            y: visibleFrame.midY - windowSize.height / 2
        )
        window.setFrameOrigin(origin)
    }
}

@MainActor
public final class RCMFeedbackWindowPresenter {
    public static let shared = RCMFeedbackWindowPresenter()

    private var window: NSWindow?

    public init() {}

    public func show(title: String = packageL(MySwiftAppToolsL10n.helpCenterFeedback)) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(
            rootView: FeedbackView()
                .frame(minWidth: 560, minHeight: 520)
        )
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        newWindow.title = title
        newWindow.contentViewController = hostingController
        newWindow.center()
        newWindow.isReleasedWhenClosed = false
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        window = newWindow
    }
}
#endif

// MARK: - Help Button

public struct RCMHelpButton: View {
    public enum Size {
        case toolbar
        case large

        var height: CGFloat {
            switch self {
            case .toolbar: return 34
            case .large: return 48
            }
        }

        var iconFrame: CGFloat {
            switch self {
            case .toolbar: return 22
            case .large: return 26
            }
        }

        var iconFontSize: CGFloat {
            switch self {
            case .toolbar: return 22
            case .large: return 26
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .toolbar: return RCMTheme.shared.spacing.sm
            case .large: return RCMTheme.shared.spacing.md
            }
        }

        var dotSize: CGFloat {
            switch self {
            case .toolbar: return 7
            case .large: return 9
            }
        }
    }

    @State private var manager: RCMHelpCenterManager

    private let title: String
    private let systemImage: String
    private let size: Size
    private let action: () -> Void

    public init(
        title: String = packageL(MySwiftAppToolsL10n.helpCenterHelp),
        systemImage: String = "questionmark.circle",
        size: Size = .toolbar,
        manager: RCMHelpCenterManager = .shared,
        action: @escaping () -> Void = {
#if os(macOS)
            RCMHelpCenterWindowPresenter.shared.show()
#endif
        }
    ) {
        self._manager = State(initialValue: manager)
        self.title = title
        self.systemImage = systemImage
        self.size = size
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: RCMTheme.shared.spacing.sm) {
                Image(systemName: systemImage)
                    .font(.system(size: size.iconFontSize, weight: .regular))
                    .foregroundStyle(RCMTheme.shared.colors.textSecondary)
                    .frame(width: size.iconFrame, height: size.iconFrame)

                Text(title)
                    .font(RCMTheme.shared.typography.bodyStrong)
                    .foregroundStyle(RCMTheme.shared.colors.textPrimary)
            }
            .padding(.horizontal, size.horizontalPadding)
            .frame(height: size.height)
            .background(
                Capsule(style: .continuous)
                    .fill(RCMTheme.shared.colors.cardGrayBackground)
            )
            .contentShape(Capsule(style: .continuous))
            .overlay(alignment: .topTrailing) {
                if manager.hasUnreadUpdates {
                    RCMUnreadDot(color: manager.unreadColor, size: size.dotSize)
                        .offset(x: -5, y: 5)
                }
            }
        }
        .buttonStyle(.plain)
        .help(title)
    }
}

// MARK: - Version History List

public struct RCMVersionHistoryListView: View {
    @State private var manager: RCMHelpCenterManager

    private let title: String
    private let subtitle: String?

    public init(
        title: String = packageL(MySwiftAppToolsL10n.helpCenterTitle),
        subtitle: String? = packageL(MySwiftAppToolsL10n.helpCenterVersionHistorySubtitle),
        preferredPlatform: RCMHelpVideoPreferredPlatform = .automatic,
        manager: RCMHelpCenterManager = .shared
    ) {
        self._manager = State(initialValue: manager)
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        ScrollView {
            RCMPageStack(maxWidth: 820) {
                header
                quickLinksSection
                versionHistorySection
                faqSection
            }
        }
    }

    @ViewBuilder
    private var quickLinksSection: some View {
        if !manager.quickLinks.isEmpty {
            VStack(alignment: .leading, spacing: RCMTheme.shared.spacing.sm) {
                RCMSectionTitle(title: packageL(MySwiftAppToolsL10n.helpCenterQuickLinks))

                LazyVGrid(
                    columns: [
                        GridItem(.adaptive(minimum: 180), spacing: RCMTheme.shared.spacing.sm)
                    ],
                    alignment: .leading,
                    spacing: RCMTheme.shared.spacing.sm
                ) {
                    ForEach(manager.quickLinks) { link in
                        RCMHelpQuickLinkButton(link: link, manager: manager)
                    }
                }
            }
        }
    }

    private var versionHistorySection: some View {
        VStack(alignment: .leading, spacing: RCMTheme.shared.spacing.sm) {
            RCMSectionTitle(title: packageL(MySwiftAppToolsL10n.helpCenterVersionHistory))

            if manager.items.isEmpty {
                RCMGroup {
                    RCMEmptyState(
                        systemImage: "clock.arrow.circlepath",
                        title: LocalizedStringKey(packageL(MySwiftAppToolsL10n.helpCenterNoVersionHistory)),
                        message: LocalizedStringKey(packageL(MySwiftAppToolsL10n.helpCenterNoVersionHistoryMessage))
                    )
                }
            } else {
                LazyVStack(spacing: RCMTheme.shared.spacing.md) {
                    ForEach(manager.items) { item in
                            RCMVersionHistoryRow(
                                item: item,
                                isUnread: manager.isUnread(item),
                                accentColor: manager.accentColor,
                                unreadColor: manager.unreadColor,
                                markAsRead: {
                                    manager.markAsRead(item)
                            }
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var faqSection: some View {
        if !manager.faqItems.isEmpty {
            VStack(alignment: .leading, spacing: RCMTheme.shared.spacing.sm) {
                RCMSectionTitle(title: packageL(MySwiftAppToolsL10n.helpCenterFAQ))

                RCMGroup {
                    VStack(spacing: 0) {
                        ForEach(Array(manager.faqItems.enumerated()), id: \.element.id) { index, item in
                            RCMHelpFAQRow(item: item)

                            if index < manager.faqItems.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: RCMTheme.shared.spacing.md) {
            RCMSectionTitle(title: title, subtitle: subtitle)

            Spacer(minLength: RCMTheme.shared.spacing.md)

            HStack(spacing: RCMTheme.shared.spacing.sm) {
                if let supportURL = manager.supportURL {
                    RCMHelpActionButton(role: .soft, accentColor: manager.accentColor, action: {
#if os(macOS)
                        NSWorkspace.shared.open(supportURL)
#endif
                    }) {
                        Label(packageL(MySwiftAppToolsL10n.helpCenterOpenSupport), systemImage: "safari")
                    }
                }

                RCMHelpActionButton(role: .secondary, accentColor: manager.accentColor, action: {
                    manager.markAllAsRead()
                }) {
                    Label(packageL(MySwiftAppToolsL10n.helpCenterMarkAllRead), systemImage: "checkmark.circle")
                }
                .disabled(!manager.hasUnreadUpdates)
            }
        }
    }
}

private struct RCMHelpQuickLinkButton: View {
    @Environment(\.openURL) private var openURL

    let link: RCMHelpQuickLinkItem
    let manager: RCMHelpCenterManager

    var body: some View {
        Button(action: performAction) {
            HStack(alignment: .center, spacing: RCMTheme.shared.spacing.sm) {
                Image(systemName: link.systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(manager.accentColor)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: RCMTheme.shared.spacing.xxs) {
                    Text(link.title)
                        .font(RCMTheme.shared.typography.bodyStrong)
                        .foregroundStyle(RCMTheme.shared.colors.textPrimary)
                        .lineLimit(1)

                    if let subtitle = link.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(RCMTheme.shared.typography.caption)
                            .foregroundStyle(RCMTheme.shared.colors.textSecondary)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: RCMTheme.shared.spacing.xs)
            }
            .padding(RCMTheme.shared.spacing.md)
            .frame(maxWidth: .infinity, minHeight: 84, maxHeight: 84, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: RCMTheme.shared.radius.md, style: .continuous)
                    .fill(RCMTheme.shared.colors.cardGrayBackground)
            )
            .contentShape(RoundedRectangle(cornerRadius: RCMTheme.shared.radius.md, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func performAction() {
        switch link.action {
        case .url(let url):
            openURL(url)
        case .feedback:
#if os(macOS)
            RCMFeedbackWindowPresenter.shared.show()
#endif
        case .appStoreReview:
#if os(macOS)
            if let appleID = FeedbackManager.shared.config?.appleID {
                AppStoreHelper.rateApp(appleID: appleID)
            }
#endif
        case .support:
            if let url = manager.supportURL {
                openURL(url)
            } else if let supportURL = FeedbackManager.shared.config?.supportURL,
                      let url = URL(string: supportURL) {
                openURL(url)
            }
        }
    }
}

private struct RCMHelpFAQRow: View {
    let item: RCMHelpFAQItem

    var body: some View {
        DisclosureGroup {
            Text(item.answer)
                .font(RCMTheme.shared.typography.body)
                .foregroundStyle(RCMTheme.shared.colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, RCMTheme.shared.spacing.xs)
        } label: {
            Text(item.question)
                .font(RCMTheme.shared.typography.bodyStrong)
                .foregroundStyle(RCMTheme.shared.colors.textPrimary)
        }
        .padding(.vertical, RCMTheme.shared.spacing.sm)
    }
}

private struct RCMHelpActionButton<LabelContent: View>: View {
    enum Role {
        case soft
        case secondary
    }

    let role: Role
    let accentColor: Color
    let action: () -> Void
    @ViewBuilder let label: () -> LabelContent

    var body: some View {
        Button(action: action) {
            label()
                .font(RCMTheme.shared.typography.bodyStrong)
                .foregroundStyle(accentColor)
                .frame(height: RCMTheme.shared.controlSize.buttonHeight)
                .padding(.horizontal, RCMTheme.shared.spacing.md)
                .background(background)
                .contentShape(RoundedRectangle(cornerRadius: RCMTheme.shared.radius.md, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var background: some View {
        switch role {
        case .soft:
            RoundedRectangle(cornerRadius: RCMTheme.shared.radius.md, style: .continuous)
                .fill(accentColor.opacity(0.12))
        case .secondary:
            RoundedRectangle(cornerRadius: RCMTheme.shared.radius.md, style: .continuous)
                .stroke(accentColor, lineWidth: 1.5)
        }
    }
}

private struct RCMVersionHistoryRow: View {
    @Environment(\.openURL) private var openURL

    let item: RCMVersionHistoryItem
    let isUnread: Bool
    let accentColor: Color
    let unreadColor: Color
    let markAsRead: () -> Void

    var body: some View {
        RCMGroup(showsBorder: isUnread) {
            VStack(alignment: .leading, spacing: RCMTheme.shared.spacing.md) {
                header

                Text(item.changes)
                    .font(RCMTheme.shared.typography.body)
                    .foregroundStyle(RCMTheme.shared.colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if let videoTitle = item.videoTitle, !videoTitle.isEmpty {
                    Text(videoTitle)
                        .font(RCMTheme.shared.typography.caption)
                        .foregroundStyle(RCMTheme.shared.colors.textSecondary)
                }

                actions
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: RCMTheme.shared.spacing.sm) {
            if isUnread {
                RCMUnreadDot(color: unreadColor)
            }

            Text(item.versionName)
                .font(RCMTheme.shared.typography.bodyStrong)
                .foregroundStyle(RCMTheme.shared.colors.textPrimary)

            if isUnread {
                RCMUnreadBadge(text: packageL(MySwiftAppToolsL10n.helpCenterNew), color: unreadColor)
            }

            Spacer(minLength: RCMTheme.shared.spacing.md)

            Text(formattedDate(item.publishedAt))
                .font(RCMTheme.shared.typography.caption)
                .foregroundStyle(RCMTheme.shared.colors.textSecondary)
        }
    }

    private var actions: some View {
        HStack(spacing: RCMTheme.shared.spacing.sm) {
            if let bilibiliURL = item.videoLinks.bilibiliURL {
                RCMHelpActionButton(role: .soft, accentColor: accentColor, action: {
                    open(bilibiliURL)
                }) {
                    Label(packageL(MySwiftAppToolsL10n.helpCenterBilibili), systemImage: "play.rectangle")
                }
            }

            if let youtubeURL = item.videoLinks.youtubeURL {
                RCMHelpActionButton(role: .soft, accentColor: accentColor, action: {
                    open(youtubeURL)
                }) {
                    Label(packageL(MySwiftAppToolsL10n.helpCenterYoutube), systemImage: "play.rectangle")
                }
            }
        }
    }

    private func open(_ url: URL) {
        markAsRead()
        openURL(url)
    }

    private func formattedDate(_ date: Date) -> String {
        date.formatted(.dateTime.year().month().day())
    }
}

private struct RCMUnreadDot: View {
    var color: Color
    var size: CGFloat = 8

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .accessibilityLabel(packageL(MySwiftAppToolsL10n.helpCenterUnread))
    }
}

private struct RCMUnreadBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(RCMTheme.shared.typography.captionStrong)
            .foregroundStyle(color)
            .padding(.horizontal, RCMTheme.shared.spacing.xs)
            .padding(.vertical, RCMTheme.shared.spacing.xxs)
            .background(
                Capsule(style: .continuous)
                    .fill(color.opacity(0.12))
            )
    }
}
