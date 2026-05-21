import SwiftUI

// MARK: - Help Center Preview

public struct RCMHelpCenterPreview: View {
    @State private var manager = RCMHelpCenterManager()

    public init() {}

    public var body: some View {
        VStack(spacing: RCMTheme.shared.spacing.lg) {
            RCMHelpButton(
                title: packageL(MySwiftAppToolsL10n.helpCenterHelp),
                manager: manager
            ) {
#if os(macOS)
                RCMHelpCenterWindowPresenter.shared.show(manager: manager)
#endif
            }

            RCMCaptionText("Click the button to open the HelpCenter window.")
        }
        .padding(RCMTheme.shared.spacing.xxl)
        .onAppear {
            configurePreviewData()
        }
    }

    private func configurePreviewData() {
        RCMHelpCenterPreviewData.configure(manager)
    }
}

@MainActor
private enum RCMHelpCenterPreviewData {
    static func makeManager() -> RCMHelpCenterManager {
        let manager = RCMHelpCenterManager()
        configure(manager)
        return manager
    }

    static func configure(_ manager: RCMHelpCenterManager) {
        FeedbackManager.shared.configure(
            appleID: "123456789",
            supportURL: "https://example.com/support",
            appName: "Preview App"
        )

        manager.configure(
            items: items,
            storageKey: "MySwiftAppTools.RCMHelpCenterPreview.lastViewedPublishedAt",
            supportURL: URL(string: "https://example.com/support"),
            quickLinks: quickLinks,
            faqItems: faqItems,
            unreadColor: .blue,
            markExistingItemsAsReadOnFirstConfigure: false
        )
    }

    private static var quickLinks: [RCMHelpQuickLinkItem] {
        [
            RCMHelpQuickLinkItem(
                title: "Getting Started",
                subtitle: "Open the online guide",
                systemImage: "book",
                url: URL(string: "https://example.com/guide")!
            ),
            RCMHelpQuickLinkItem(
                title: "Video Tutorials",
                subtitle: "Watch feature walkthroughs",
                systemImage: "play.rectangle",
                url: URL(string: "https://www.youtube.com")!
            )
        ]
    }

    private static var faqItems: [RCMHelpFAQItem] {
        [
            RCMHelpFAQItem(
                question: "How do I get started?",
                answer: "Import your first file, choose a preset, then run the main action. The exact workflow is provided by the host app."
            ),
            RCMHelpFAQItem(
                question: "Why do I see a red dot?",
                answer: "The dot means there are version notes newer than the last item you opened or marked as read."
            ),
            RCMHelpFAQItem(
                question: "Where should I report a problem?",
                answer: "Use the feedback entry in Quick Links. It opens the shared feedback window with system information support."
            )
        ]
    }

    private static var items: [RCMVersionHistoryItem] {
        [
            RCMVersionHistoryItem(
                versionName: "v1.2.0",
                publishedAt: Date(),
                changes: "1. Added HelpCenter window preview\n2. Improved toolbar button style\n3. Added support and mark-as-read actions",
                videoTitle: "Release walkthrough",
                bilibiliURL: URL(string: "https://www.bilibili.com"),
                youtubeURL: URL(string: "https://www.youtube.com")
            ),
            RCMVersionHistoryItem(
                versionName: "v1.1.5",
                publishedAt: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date(),
                changes: "Added English localization and improved onboarding.",
                videoTitle: nil
            ),
            RCMVersionHistoryItem(
                versionName: "v1.1.4",
                publishedAt: Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date(),
                changes: "1. Fixed bugs\n2. Improved purchase UI\n3. Added voice clone support",
                videoTitle: "Version 1.1.4 overview",
                youtubeURL: URL(string: "https://www.youtube.com")
            )
        ]
    }
}

#Preview {
    RCMHelpCenterPreview()
        .frame(width: 360, height: 180)
}

#Preview {
    RCMVersionHistoryListView(manager: RCMHelpCenterPreviewData.makeManager())
        .frame(width: 820, height: 680)
}
