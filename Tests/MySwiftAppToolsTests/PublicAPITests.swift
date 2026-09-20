import SwiftUI
import XCTest
import MySwiftAppTools

@MainActor
final class PublicAPITests: XCTestCase {
    func testPackageLocalizationReturnsBundleString() {
        let value = packageL(MySwiftAppToolsL10n.confirmOK)
        XCTAssertFalse(value.isEmpty)
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
        DefaultsTools.configure(appGroupID: nil)
    }

    func testDefaultsToolsUsesStandardStorageWithoutAppGroup() {
        let key = "DefaultsTools.standard.\(UUID().uuidString)"
        defer {
            UserDefaults.standard.removeObject(forKey: key)
            DefaultsTools.configure(appGroupID: nil)
        }

        DefaultsTools.configure(appGroupID: nil)
        DefaultsTools.shared.set("standard", forStringKey: key)

        XCTAssertEqual(UserDefaults.standard.string(forKey: key), "standard")
        XCTAssertEqual(DefaultsTools.appGroupID, "")
    }

    func testDefaultsToolsCanReturnToStandardStorage() {
        DefaultsTools.configure(appGroupID: "  ")
        XCTAssertEqual(DefaultsTools.appGroupID, "")
    }

    func testFileToolsCreatesParentDirectories() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MySwiftAppToolsTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("nested/file.txt")

        try FileTools.createFile(at: file)

        XCTAssertTrue(FileTools.exists(file))
        XCTAssertTrue(FileTools.isDirectory(file.deletingLastPathComponent()))
    }

    func testEnsureDirectoryRejectsExistingFile() throws {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("MySwiftAppToolsTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: file) }
        XCTAssertTrue(FileManager.default.createFile(atPath: file.path, contents: Data()))

        XCTAssertThrowsError(try FileTools.ensureDirectory(file)) { error in
            XCTAssertEqual(error as? FileToolsError, .pathIsNotDirectory(file))
        }
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

    @MainActor
    func testToastHistoryPublicEntrypointsCompile() {
        defer {
            DefaultsTools.shared.remove(forStringKey: ToastHistoryStore.storageKey)
        }

        // 存储层公开入口：读取与增删（配置属性对外只读）
        XCTAssertEqual(ToastHistoryStore.storageKey, "MySwiftAppTools.Toast.history.v1")
        let store = ToastHistoryStore()

        store.record(message: "冒烟", type: .normal)
        XCTAssertEqual(store.records.count, 1)
        XCTAssertEqual(store.records.first?.message, "冒烟")

        store.flush()
        store.reload()
        if let first = store.records.first {
            store.delete(id: first.id)
        }
        XCTAssertTrue(store.records.isEmpty)

        // 唯一的公开配置入口：ToastManager.configureToastHistory
        ToastManager.shared.configureToastHistory(
            maxCount: 10,
            isHistoryEnabled: true,
            excludedTypes: [],
            maxMessageLength: 100,
            maxTotalBytes: 64 * 1024,
            deferredPersist: false
        )
        ToastManager.shared.configureToastHistory(maxCount: 12)
        XCTAssertEqual(ToastManager.shared.toastHistory.maxCount, 12)
        XCTAssertEqual(ToastManager.shared.toastHistory.maxMessageLength, 100)
        XCTAssertTrue(ToastManager.shared.toastHistory.excludedTypes.isEmpty)
        XCTAssertFalse(ToastManager.shared.toastHistory.hasPendingChanges)

        // ToastRecord 的公开构造与读取
        let record = ToastRecord(message: "r", type: .warning, position: .bottom)
        XCTAssertEqual(record.type, .warning)
        XCTAssertEqual(record.position, .bottom)
        XCTAssertFalse(record.message.isEmpty)
        XCTAssertNotNil(record.id)
        XCTAssertNotNil(record.createdAt)

        // ToastManager 转发入口
        XCTAssertTrue(ToastManager.shared.toastHistory === ToastHistoryStore.shared)
        XCTAssertTrue(ToastManager.shared.history === ToastHistoryStore.shared)
        _ = ToastManager.shared.toastHistory.records

        // 界面与窗口控制器的公开构造
        _ = ToastHistoryView()
        _ = ToastHistoryView(store: store, pageSize: 5, showsClearAllButton: false)
        _ = ToastHistoryView(store: store, onClose: {})
        _ = ToastHistoryWindowController.shared
        _ = ToastHistoryWindowController.shared.isVisible
        ToastHistoryWindowController.shared.close()

        // 本地化文案键可查到包内字符串
        XCTAssertFalse(packageL(MySwiftAppToolsL10n.toastHistoryTitle).isEmpty)
        XCTAssertFalse(packageL(MySwiftAppToolsL10n.toastHistoryMore, 3).isEmpty)
    }
}
