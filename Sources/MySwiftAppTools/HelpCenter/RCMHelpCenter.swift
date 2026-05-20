import Foundation
import SwiftUI

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

    private var defaults: UserDefaults = .standard
    private var storageKey = "MySwiftAppTools.RCMHelpCenter.lastViewedPublishedAt"
    private var isConfigured = false

    public init() {}

    public func configure(
        items: [RCMVersionHistoryItem],
        storageKey: String,
        defaults: UserDefaults = .standard,
        markExistingItemsAsReadOnFirstConfigure: Bool = true
    ) {
        self.items = items.sorted { $0.publishedAt > $1.publishedAt }
        self.storageKey = storageKey
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

// MARK: - Help Button

public struct RCMHelpButton: View {
    @State private var manager: RCMHelpCenterManager

    private let title: String
    private let systemImage: String
    private let role: RCMButton.Role
    private let action: () -> Void

    public init(
        title: String = packageL(MySwiftAppToolsL10n.helpCenterHelp),
        systemImage: String = "questionmark.circle",
        role: RCMButton.Role = .soft,
        manager: RCMHelpCenterManager = .shared,
        action: @escaping () -> Void
    ) {
        self._manager = State(initialValue: manager)
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.action = action
    }

    public var body: some View {
        RCMButton(role, action: action) {
            Label(title, systemImage: systemImage)
                .overlay(alignment: .topTrailing) {
                    if manager.hasUnreadUpdates {
                        RCMUnreadDot()
                            .offset(x: 8, y: -8)
                    }
                }
        }
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
                RCMSectionTitle(title: title, subtitle: subtitle)

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
            RCMButton(.primary, action: openPreferredVideoOrMarkRead) {
                Label(packageL(MySwiftAppToolsL10n.helpCenterViewContent), systemImage: "play.circle")
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

    private func openPreferredVideoOrMarkRead() {
        if let url = item.preferredVideoURL(preferredPlatform) {
            open(url)
        } else {
            markAsRead()
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
    var body: some View {
        Circle()
            .fill(RCMTheme.shared.colors.danger)
            .frame(width: 8, height: 8)
            .accessibilityLabel(packageL(MySwiftAppToolsL10n.helpCenterUnread))
    }
}
