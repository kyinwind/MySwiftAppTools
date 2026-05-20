import SwiftUI
import XCTest
import MySwiftAppTools

@MainActor
final class PublicAPITests: XCTestCase {
    func testDesignSystemPublicEntrypointsCompile() throws {
        try RCMTheme.shared.applyDefaultThemeFromPackage()
        RCMTheme.shared.applyPreset(.orange)
        RCMTheme.shared.configure { tokens in
            tokens.colors.primary = Color(hexRGB: "#3185FF")
            tokens.spacing.md = 16
        }
        
        let partialJSON = """
        {
          "colors": { "primary": "#FF6B00" },
          "shadow": { "opacity": 0.08 }
        }
        """.data(using: .utf8)!
        try RCMTheme.shared.configure(jsonData: partialJSON)
        
        _ = RCMButton("保存", role: .primary, systemImage: "checkmark") {}
        _ = RCMBadge("Pro", style: .accent)
        let badgeText = "String Variable"
        _ = RCMBadge(badgeText, style: .success)
        _ = RCMBadge(verbatim: "1.0.0", style: .neutral)
        _ = RCMToggle(isOn: .constant(true), localizedLabel: "自动更新")
        _ = RCMCard { Text("Card") }
        _ = RCMPage("设置", subtitle: "管理应用偏好") {
            RCMPageSection("通用") {
                RCMGroup {
                    Text("Content")
                }
            }
        }
        _ = RCMPageStack(title: "设置") {
            RCMPageSection("通用") {
                Text("Content")
            }
        }
        _ = RCMGroup("分组", subtitle: "说明") { Text("Group") }
        _ = RCMGroup(showsBorder: true) { Text("Group") }
        _ = RCMPageSection("设置") { Text("Content") }
        _ = RCMHeroPanel { Text("Hero") }
        _ = RCMSettingRow("标题", subtitle: "说明") { Text("Value") }
        _ = RCMFlowLayout { Text("Flow") }
        _ = RCMPill("标签", tone: RCMPillTone.defaultPalette[0], action: {})
        _ = RCMPillFlow(["2560x1600", "50%", "1280x720"], sortOrder: .ascending, minItemWidth: 96, showsRemoveButton: true)
        _ = RCMEmptyState(systemImage: "tray", title: "暂无内容", message: "创建第一条记录后会显示在这里。", actionTitle: "新增") {}
        _ = RCMErrorState(title: "加载失败", message: "请稍后重试。", actionTitle: "重试") {}
        _ = RCMLoadingState("正在加载", message: "这通常只需要几秒。")
        _ = RCMProgressPanel("模型下载", subtitle: "LaMa.mlpackage.zip", fractionCompleted: 0.5, statusText: "50%", actionTitle: "取消") {}
        let helpItem = RCMVersionHistoryItem(
            versionName: "v1.0.0",
            publishedAt: Date(timeIntervalSince1970: 100),
            changes: "初始版本",
            videoTitle: "版本介绍",
            bilibiliURL: URL(string: "https://www.bilibili.com/video/test"),
            youtubeURL: URL(string: "https://www.youtube.com/watch?v=test")
        )
        let helpManager = RCMHelpCenterManager()
        helpManager.configure(
            items: [helpItem],
            storageKey: "MySwiftAppToolsTests.HelpCenter.\(UUID().uuidString)",
            supportURL: URL(string: "https://example.com/support"),
            markExistingItemsAsReadOnFirstConfigure: false
        )
        XCTAssertEqual(helpManager.supportURL, URL(string: "https://example.com/support"))
        XCTAssertTrue(helpManager.hasUnreadUpdates)
        XCTAssertTrue(helpManager.isUnread(helpItem))
        helpManager.markAsRead(helpItem)
        XCTAssertFalse(helpManager.hasUnreadUpdates)
        _ = RCMHelpButton(manager: helpManager) {}
        _ = RCMVersionHistoryListView(manager: helpManager)
        _ = RCMDesignSystemGallery()
    }
    
    func testColorHexFormatsKeepEightDigitSemanticsExplicit() {
        XCTAssertEqual(Color(hexRGB: "#FF0000").toHex(), "#FF0000")
        XCTAssertEqual(Color(hexARGB: "#FF0000FF").toHex(), "#0000FF")
        XCTAssertEqual(Color(hexRGBA: "#FF0000FF").toHex(), "#FF0000")
        XCTAssertEqual(Color(hex: "#FF0000FF", format: .rgba).toHex(), "#FF0000")
    }
    
    func testToolPublicEntrypointsCompile() async {
        DefaultsTools.configure(appGroupID: "MySwiftAppToolsTests")
        DefaultsTools.shared.set("value", for: "public.api.test")
        XCTAssertEqual(DefaultsTools.shared.string("public.api.test"), "value")
        DefaultsTools.shared.remove("public.api.test")
        
        let typedKey: DefaultsTools.Key = "public.api.typed"
        let date = Date(timeIntervalSince1970: 100)
        let url = URL(fileURLWithPath: "/tmp/defaults-tools")
        let data = Data([1, 2, 3])
        DefaultsTools.shared.set(Float(1.5), for: typedKey)
        XCTAssertEqual(DefaultsTools.shared.float(typedKey), Float(1.5))
        DefaultsTools.shared.set(date, for: "public.api.date")
        XCTAssertEqual(DefaultsTools.shared.date("public.api.date"), date)
        DefaultsTools.shared.set(url, for: "public.api.url")
        XCTAssertEqual(DefaultsTools.shared.url("public.api.url"), url)
        DefaultsTools.shared.set(data, for: "public.api.data")
        XCTAssertEqual(DefaultsTools.shared.data("public.api.data"), data)
        DefaultsTools.shared.set(["a", "b"], for: "public.api.array")
        XCTAssertEqual(DefaultsTools.shared.stringArray("public.api.array"), ["a", "b"])
        DefaultsTools.shared.set(["count": 2], for: "public.api.dictionary")
        XCTAssertEqual(DefaultsTools.shared.dictionary("public.api.dictionary", as: Int.self)?["count"], 2)
        DefaultsTools.shared.setCodable(["name": "tools"], for: "public.api.codable")
        XCTAssertEqual(DefaultsTools.shared.codable([String: String].self, for: "public.api.codable")?["name"], "tools")
        
        KeychainTools.configure(defaultService: "MySwiftAppToolsTests")
        Log.configure(subsystem: "MySwiftAppToolsTests", isEnabled: false)
        
        ToastManager.shared.configure(maxVisibleToasts: 3)
        ToastManager.shared.show("测试", duration: 0.01)
        ToastManager.shared.hideAll()
        
        _ = AutoLaunchManager.shared
        _ = AutoLaunchManager.shared.isEnabled
        
        _ = StoreManager(productIDs: ["test.product"], proProductID: "test.product", autoStart: false)
        
        ProGatekeeper.shared.configure(
            freeLimits: ["feature": 1],
            keyPrefix: "MySwiftAppToolsTests.ProGatekeeper",
            hasPurchasedPro: { false },
            presentPurchase: {}
        )
        _ = ProGatekeeper.shared.allow("feature")
        
        _ = ComponentState(isBusy: false, isFinished: true)
        _ = ComponentsFlowManager<String, String>()
        _ = PermissionManager.shared
        
        let suiteName = "MySwiftAppToolsTests.DirectoryManager.\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName) ?? .standard
        DirectoryManager.configure(userDefaults: suite)
        DirectoryManager.save([
            MyDirectory(url: URL(fileURLWithPath: "/tmp"), label: "tmp", type: .history)
        ])
        XCTAssertEqual(DirectoryManager.loadHistory().first?.label, "tmp")
        DirectoryManager.save([])
        DirectoryManager.resetStorageToStandard()
    }
    
    @MainActor
    private final class TestStateBox {
        var lastProgress: Double = 0.0
        var lastSpeed: Double = 0.0
    }

    @MainActor
    func testMultiSourceDownloaderAPICompile() {
        // 此测试仅验证 API 编译正确性，不依赖真实网络。
        // 实际下载测试请在有网络的环境中手动运行。

        let urls = [
            URL(string: "https://www.modelscope.cn/models/kylinwind/Lama-Inpainting-Swift/resolve/master/LaMa.mlpackage.zip")!,
            URL(string: "https://github.com/kyinwind/MichaelDevStudio/releases/download/1.0.0/LaMa.mlpackage.zip")!
        ]
        let destination = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test.zip")
        let sha256 = "15021d7a4cab01279edc78cdd8fa78c35584d8c3050309682ffa0944603d78bd"

        let downloader = MultiSourceDownloader(
            urls: urls,
            destinationURL: destination,
            hashAlgorithm: .sha256,
            expectedHash: sha256,
            configuration: .init(
                maxRetryCount: 2,
                requestTimeout: 10,
                probeTimeout: 3,
                allowsCrossSourceResume: false
            )
        )

        XCTAssertEqual(downloader.urls, urls)
        XCTAssertEqual(downloader.destinationURL, destination)
        XCTAssertEqual(downloader.hashAlgorithm, .sha256)
        XCTAssertEqual(downloader.expectedHash, sha256)
        XCTAssertEqual(downloader.configuration.maxRetryCount, 2)

        let progress = MultiSourceDownloader.Progress(
            fractionCompleted: 0.5,
            downloadedBytes: 500,
            totalBytes: 1000,
            speed: 1_500,
            remainingSeconds: 10
        )
        XCTAssertEqual(progress.formattedSpeed, "1.5 KB/s")
        XCTAssertEqual(progress.formattedRemainingTime, "0:10")
    }
}
