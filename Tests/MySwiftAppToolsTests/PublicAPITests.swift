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
        _ = RCMGroup("分组", subtitle: "说明") { Text("Group") }
        _ = RCMGroup(showsBorder: true) { Text("Group") }
        _ = RCMPageSection("设置") { Text("Content") }
        _ = RCMHeroPanel { Text("Hero") }
        _ = RCMSettingRow("标题", subtitle: "说明") { Text("Value") }
        _ = RCMFlowLayout { Text("Flow") }
        _ = RCMPill("标签", tone: RCMPillTone.defaultPalette[0], action: {})
        _ = RCMPillFlow(["2560x1600", "50%", "1280x720"], sortOrder: .ascending, minItemWidth: 96, showsRemoveButton: true)
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
    }

    @MainActor
    func testMultiSourceDownloader() async throws {
        // 1. 准备测试用的模型下载链接（您的真实魔塔源与 GitHub 源）
        guard let domesticURL = URL(string: "https://www.modelscope.cn/models/kylinwind/Lama-Inpainting-Swift/file/view/master/LaMa.mlpackage.zip?status=2"),
              let internationalURL = URL(string: "https://github.com/kyinwind/MichaelDevStudio/releases/download/1.0.0/LaMa.mlpackage.zip") else {
            XCTFail("测试 URL 初始化失败")
            return
        }
        
        // 2. 准备本地存放路径
        let fileManager = FileManager.default
        let temporaryDirectory = fileManager.temporaryDirectory
        let testDestinationURL = temporaryDirectory.appendingPathComponent("test_model.zip")
        
        if fileManager.fileExists(atPath: testDestinationURL.path) {
            try? fileManager.removeItem(at: testDestinationURL)
        }
        
        // 3. 您文件的真实预期 SHA256 校验码
        let expectedHash = "15021d7a4cab01279edc78cdd8fa78c35584d8c3050309682ffa0944603d78bd"
        
        let downloader = MultiSourceDownloader(
            urls: [domesticURL, internationalURL],
            destinationURL: testDestinationURL,
            expectedSHA256: expectedHash
        )
        
        // 4. 优化 Expectation 逻辑：必须等待进度彻底达到 100% (1.0) 才能算是真正“满足预期”
        let progressExpectation = XCTestExpectation(description: "大模型文件必须完全下载成功并达到 100%")
        
        let stateBox = TestStateBox()
        
        do {
            // 5. 启动异步下载
            try await downloader.startDownload { @Sendable progress in
                Task { @MainActor in
                    stateBox.lastProgress = progress
                    print("当前模型下载进度: \(String(format: "%.2f", progress * 100))%")
                    
                    // 🚨 核心优化 1：只有当进度完美归位 1.0 时，才允许释放信号闸门
                    if progress >= 1.0 {
                        progressExpectation.fulfill()
                    }
                }
            }
            
            // 🚨 核心优化 2：利用系统机制给多线程调度留出最后一丝同步时间隙
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2秒
            
            // 6. 断言验证
            XCTAssertTrue(fileManager.fileExists(atPath: testDestinationURL.path), "错误：下载流程走完，但本地未找到落地文件")
            XCTAssertEqual(stateBox.lastProgress, 1.0, accuracy: 0.01, "错误：下载已结束，但最终进度停留在了 \(stateBox.lastProgress)")
            
            print("🎉 测试通过：真实的 LaMa 大模型文件下载并顺利通过 SHA256 强校验！")
            
        } catch {
            XCTFail("下载测试由于错误中断: \(error.localizedDescription)")
        }
        
        // 🚨 核心优化 3：大模型体积较大，国内网络波动下载需要时间，将超时阈值放宽至 5 分钟
        await fulfillment(of: [progressExpectation], timeout: 300.0)
        
        // 7. 清理大文件残留，释放 Mac 磁盘空间
        try? fileManager.removeItem(at: testDestinationURL)
    }

    
}
