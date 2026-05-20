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
    public private(set) var lastViewedPublishedAt: Date = .distantPast
    public private(set) var supportURL: URL?

    private var defaults: UserDefaults = .standard
    private var storageKey = "MySwiftAppTools.RCMHelpCenter.lastViewedPublishedAt"
    private var isConfigured = false

    public init() {}

    public func configure(
        items: [RCMVersionHistoryItem],
        storageKey: String,
        supportURL: URL? = nil,
        defaults: UserDefaults = .standard,
        markExistingItemsAsReadOnFirstConfigure: Bool = true
    ) {
        self.items = items.sorted { $0.publishedAt > $1.publishedAt }
        self.storageKey = storageKey
        self.supportURL = supportURL
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
}

// MARK: - Help Center Window

#if os(macOS)
@MainActor
public final class RCMHelpCenterWindowPresenter {
    public static let shared = RCMHelpCenterWindowPresenter()

    private var window: NSWindow?

    public init() {}

    public func show(
        title: String = packageL(MySwiftAppToolsL10n.helpCenterVersionHistory),
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
            preferredPlatform: preferredPlatform,
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
            case .toolbar: return 24
            case .large: return 28
            }
        }

        var iconFontSize: CGFloat {
            switch self {
            case .toolbar: return 15
            case .large: return 18
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
                    .font(.system(size: size.iconFontSize, weight: .semibold))
                    .foregroundStyle(RCMTheme.shared.colors.textSecondary)
                    .frame(width: size.iconFrame, height: size.iconFrame)
                    .background(
                        Circle()
                            .stroke(RCMTheme.shared.colors.textSecondary.opacity(0.7), lineWidth: 1.8)
                    )

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
                    RCMUnreadDot(size: size.dotSize)
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
    private let preferredPlatform: RCMHelpVideoPreferredPlatform

    public init(
        title: String = packageL(MySwiftAppToolsL10n.helpCenterVersionHistory),
        subtitle: String? = packageL(MySwiftAppToolsL10n.helpCenterVersionHistorySubtitle),
        preferredPlatform: RCMHelpVideoPreferredPlatform = .automatic,
        manager: RCMHelpCenterManager = .shared
    ) {
        self._manager = State(initialValue: manager)
        self.title = title
        self.subtitle = subtitle
        self.preferredPlatform = preferredPlatform
    }

    public var body: some View {
        ScrollView {
            RCMPageStack(maxWidth: 820) {
                header

                if manager.items.isEmpty {
                    RCMEmptyState(
                        systemImage: "clock.arrow.circlepath",
                        title: LocalizedStringKey(packageL(MySwiftAppToolsL10n.helpCenterNoVersionHistory)),
                        message: LocalizedStringKey(packageL(MySwiftAppToolsL10n.helpCenterNoVersionHistoryMessage))
                    )
                } else {
                    LazyVStack(spacing: RCMTheme.shared.spacing.md) {
                        ForEach(manager.items) { item in
                            RCMVersionHistoryRow(
                                item: item,
                                isUnread: manager.isUnread(item),
                                preferredPlatform: preferredPlatform,
                                markAsRead: {
                                    manager.markAsRead(item)
                                }
                            )
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
                    RCMButton(.soft, action: {
#if os(macOS)
                        NSWorkspace.shared.open(supportURL)
#endif
                    }) {
                        Label(packageL(MySwiftAppToolsL10n.helpCenterOpenSupport), systemImage: "safari")
                    }
                }

                RCMButton(.secondary, action: {
                    manager.markAllAsRead()
                }) {
                    Label(packageL(MySwiftAppToolsL10n.helpCenterMarkAllRead), systemImage: "checkmark.circle")
                }
                .disabled(!manager.hasUnreadUpdates)
            }
        }
    }
}

private struct RCMVersionHistoryRow: View {
    @Environment(\.openURL) private var openURL

    let item: RCMVersionHistoryItem
    let isUnread: Bool
    let preferredPlatform: RCMHelpVideoPreferredPlatform
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
                RCMUnreadDot()
            }

            Text(item.versionName)
                .font(RCMTheme.shared.typography.bodyStrong)
                .foregroundStyle(RCMTheme.shared.colors.textPrimary)

            if isUnread {
                RCMBadge(packageL(MySwiftAppToolsL10n.helpCenterNew), style: .danger)
            }

            Spacer(minLength: RCMTheme.shared.spacing.md)

            Text(formattedDate(item.publishedAt))
                .font(RCMTheme.shared.typography.caption)
                .foregroundStyle(RCMTheme.shared.colors.textSecondary)
        }
    }

    private var actions: some View {
        HStack(spacing: RCMTheme.shared.spacing.sm) {
            if item.hasVideoLinks {
                RCMButton(.primary, action: openPreferredVideo) {
                    Label(packageL(MySwiftAppToolsL10n.helpCenterViewContent), systemImage: "play.circle")
                }
            }

            if let bilibiliURL = item.videoLinks.bilibiliURL {
                RCMButton(.soft, action: {
                    open(bilibiliURL)
                }) {
                    Label(packageL(MySwiftAppToolsL10n.helpCenterBilibili), systemImage: "play.rectangle")
                }
            }

            if let youtubeURL = item.videoLinks.youtubeURL {
                RCMButton(.soft, action: {
                    open(youtubeURL)
                }) {
                    Label(packageL(MySwiftAppToolsL10n.helpCenterYoutube), systemImage: "play.rectangle")
                }
            }
        }
    }

    private func openPreferredVideo() {
        if let url = item.preferredVideoURL(preferredPlatform) {
            open(url)
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
    var size: CGFloat = 8

    var body: some View {
        Circle()
            .fill(RCMTheme.shared.colors.danger)
            .frame(width: size, height: size)
            .accessibilityLabel(packageL(MySwiftAppToolsL10n.helpCenterUnread))
    }
}
