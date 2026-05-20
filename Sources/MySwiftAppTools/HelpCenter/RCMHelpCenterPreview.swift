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
        manager.configure(
            items: items,
            storageKey: "MySwiftAppTools.RCMHelpCenterPreview.lastViewedPublishedAt",
            supportURL: URL(string: "https://example.com/support"),
            unreadColor: .blue,
            markExistingItemsAsReadOnFirstConfigure: false
        )
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
