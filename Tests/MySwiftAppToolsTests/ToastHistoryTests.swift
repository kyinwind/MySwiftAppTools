import Foundation
import XCTest
@testable import MySwiftAppTools

@MainActor
final class ToastHistoryTests: XCTestCase {

    private let suiteName = "MySwiftAppToolsTests.ToastHistory"

    override func setUp() async throws {
        DefaultsTools.configure(appGroupID: suiteName)
        resetStorage()

        // 共享单例的配置不落盘、只活在内存里，逐个测试之间会互相污染，
        // 所以每次 setUp 用给全部参数的方式复位到已知状态。
        // 注意新入口是「局部更新」语义：不传的项保持原值，这里必须传满。
        ToastManager.shared.configureToastHistory(
            maxCount: 500,
            isHistoryEnabled: true,
            excludedTypes: [.loading],
            maxMessageLength: 500,
            maxTotalBytes: 512 * 1024,
            deferredPersist: false
        )
        ToastHistoryStore.shared.clearAll()
    }

    override func tearDown() async throws {
        resetStorage()
        DefaultsTools.configure(appGroupID: nil)
    }

    private func resetStorage() {
        UserDefaults(suiteName: suiteName)?.removeObject(forKey: ToastHistoryStore.storageKey)
    }

    // MARK: - 基本读写

    func testRecordKeepsNewestFirstAndSurvivesReload() {
        let store = ToastHistoryStore()
        store.configure(maxCount: 100, excludedTypes: [])

        store.record(message: "第一条")
        store.record(message: "第二条")
        store.record(message: "第三条")

        XCTAssertEqual(store.records.map(\.message), ["第三条", "第二条", "第一条"])

        // 重新实例化，模拟 App 重启
        let reloaded = ToastHistoryStore()
        XCTAssertEqual(reloaded.records.map(\.message), ["第三条", "第二条", "第一条"])
    }

    func testRecordCarriesCreatedAt() {
        let store = ToastHistoryStore()
        store.configure(excludedTypes: [])

        let before = Date()
        store.record(message: "带时间")
        let createdAt = try? XCTUnwrap(store.records.first?.createdAt)

        XCTAssertNotNil(createdAt)
        XCTAssertGreaterThanOrEqual(createdAt ?? .distantPast, before)
    }

    func testToastRecordTypeRoundTrips() {
        let record = ToastRecord(message: "x", type: .error, position: .bottom)
        XCTAssertEqual(record.type, .error)
        XCTAssertEqual(record.position, .bottom)
    }

    // MARK: - 三重上限

    func testMaxCountDropsOldest() {
        let store = ToastHistoryStore()
        store.configure(maxCount: 3, excludedTypes: [])

        for index in 1...5 {
            store.record(message: "msg\(index)")
        }

        XCTAssertEqual(store.records.count, 3)
        XCTAssertEqual(store.records.map(\.message), ["msg5", "msg4", "msg3"])
    }

    func testMessageTruncation() {
        let store = ToastHistoryStore()
        store.configure(excludedTypes: [], maxMessageLength: 10)

        store.record(message: String(repeating: "测", count: 50))

        let message = store.records.first?.message ?? ""
        XCTAssertEqual(message.count, 11, "10 个字符 + 1 个省略号")
        XCTAssertTrue(message.hasSuffix("…"))
    }

    func testTotalBytesTrimKeepsNewest() {
        let store = ToastHistoryStore()
        // 每条估算约 430 字节，预算 512 * 0.9 ≈ 460，只能留下最新的 1 条
        store.configure(maxCount: 100, excludedTypes: [], maxTotalBytes: 512)

        for index in 1...10 {
            store.record(message: "\(index)" + String(repeating: "测", count: 99))
        }

        let kept = store.records.count
        XCTAssertTrue((1...2).contains(kept), "总字节上限应触发裁剪，实际保留 \(kept) 条")
        XCTAssertTrue(store.records.first?.message.hasPrefix("10") == true, "应保留最新的那条")
    }

    // MARK: - 过滤与开关

    func testLoadingExcludedByDefault() {
        let store = ToastHistoryStore()
        store.configure()

        store.record(message: "正常提示", type: .normal)
        store.record(message: "处理中", type: .loading)

        XCTAssertEqual(store.records.map(\.message), ["正常提示"])
    }

    func testLoadingRecordedWhenNotExcluded() {
        let store = ToastHistoryStore()
        store.configure(excludedTypes: [])

        store.record(message: "处理中", type: .loading)

        XCTAssertEqual(store.records.count, 1)
    }

    func testHistoryDisabledWritesNothing() {
        let store = ToastHistoryStore()
        store.configure(isHistoryEnabled: false, excludedTypes: [])

        store.record(message: "不该被记录")

        XCTAssertTrue(store.records.isEmpty)
        XCTAssertTrue(ToastHistoryStore().records.isEmpty)
    }

    // MARK: - 删除

    func testDeleteSingleRecord() {
        let store = ToastHistoryStore()
        store.configure(excludedTypes: [])
        store.record(message: "A")
        store.record(message: "B")

        let newest = try? XCTUnwrap(store.records.first)
        store.delete(newest ?? ToastRecord(message: "A"))

        XCTAssertEqual(store.records.map(\.message), ["A"])
        XCTAssertEqual(ToastHistoryStore().records.map(\.message), ["A"])
    }

    func testDeleteByID() {
        let store = ToastHistoryStore()
        store.configure(excludedTypes: [])
        store.record(message: "A")
        store.record(message: "B")

        let id = store.records.last?.id
        store.delete(id: id ?? UUID())

        XCTAssertEqual(store.records.map(\.message), ["B"])
    }

    func testClearAllRemovesEverything() {
        let store = ToastHistoryStore()
        store.configure(excludedTypes: [])
        store.record(message: "A")
        store.record(message: "B")

        store.clearAll()

        XCTAssertTrue(store.records.isEmpty)
        XCTAssertTrue(ToastHistoryStore().records.isEmpty)
    }

    // MARK: - 容错

    func testCorruptedDataResetsToEmpty() {
        DefaultsTools.shared.setCodable(["not a record"], forStringKey: ToastHistoryStore.storageKey)

        let store = ToastHistoryStore()

        XCTAssertTrue(store.records.isEmpty, "坏数据不能把 App 卡死，应降级为空")
        XCTAssertFalse(
            DefaultsTools.shared.exists(forStringKey: ToastHistoryStore.storageKey),
            "坏数据应被清理"
        )
    }

    func testUnknownTypeFallsBackToNormal() {
        let json = """
        [{"id":"\(UUID().uuidString)","message":"未来类型","typeRaw":"futureCase","positionRaw":"weird","createdAt":760000000}]
        """
        DefaultsTools.shared.set(Data(json.utf8), forStringKey: ToastHistoryStore.storageKey)

        let store = ToastHistoryStore()

        XCTAssertEqual(store.records.count, 1, "未知枚举值不应导致整块解码失败")
        XCTAssertEqual(store.records.first?.type, .normal)
        XCTAssertEqual(store.records.first?.position, .top)
    }

    func testReloadPicksUpExternalChanges() {
        let store = ToastHistoryStore()
        store.configure(excludedTypes: [])

        // 另一个 store 实例（模拟另一个 App / 另一处代码）写入
        let other = ToastHistoryStore()
        other.configure(excludedTypes: [])
        other.record(message: "外部写入")

        XCTAssertTrue(store.records.isEmpty, "未 reload 前应看不到外部改动")

        store.reload()

        XCTAssertEqual(store.records.map(\.message), ["外部写入"])
    }

    // MARK: - 与 ToastManager 接线

    func testShowToastFeedsHistory() {
        ToastManager.shared.configureToastHistory(excludedTypes: [])

        ToastManager.shared.show("来自 toast 的消息", duration: 0.01)

        XCTAssertEqual(ToastHistoryStore.shared.records.first?.message, "来自 toast 的消息")
        XCTAssertNotNil(ToastHistoryStore.shared.records.first?.createdAt)
    }

    func testHistoryOutlivesToastAutoDismiss() async throws {
        ToastManager.shared.configureToastHistory(excludedTypes: [])

        ToastManager.shared.show("会自己消失", duration: 0.05)
        XCTAssertEqual(ToastManager.shared.toasts.count, 1)

        try await Task.sleep(for: .milliseconds(200))

        XCTAssertTrue(ToastManager.shared.toasts.isEmpty, "toast 应已自动消失")
        XCTAssertEqual(
            ToastHistoryStore.shared.records.first?.message,
            "会自己消失",
            "toast 消失不应影响历史"
        )
    }

    func testHideAllKeepsHistory() {
        ToastManager.shared.configureToastHistory(excludedTypes: [])

        ToastManager.shared.show("清屏前的消息", duration: 10)
        ToastManager.shared.hideAll()

        XCTAssertTrue(ToastManager.shared.toasts.isEmpty)
        XCTAssertEqual(ToastHistoryStore.shared.records.first?.message, "清屏前的消息")
    }

    func testToastItemExposesCreatedAt() {
        let before = Date()

        ToastManager.shared.show("时间戳", duration: 0.01)

        let item = ToastManager.shared.toasts.last
        XCTAssertNotNil(item?.createdAt)
        XCTAssertGreaterThanOrEqual(item?.createdAt ?? .distantPast, before)
        ToastManager.shared.hideAll()
    }

    func testMinutesAgoUsesActualMinuteCount() {
        let now = Date()
        let text = ToastHistoryView.timeText(
            for: now.addingTimeInterval(-5 * 60),
            now: now
        )

        XCTAssertTrue(text.contains("5"), "分钟文案应包含实际分钟数：\(text)")
        XCTAssertFalse(text.contains("%d"), "分钟文案不应残留格式化占位符：\(text)")
    }

    // MARK: - configureToastHistory（局部更新语义）

    func testConfigureToastHistoryKeepsUnspecifiedValues() {
        let history = ToastHistoryStore.shared

        // 第一次：打开 deferredPersist
        ToastManager.shared.configureToastHistory(maxCount: 2000, deferredPersist: true)
        // 第二次：只关掉记录开关
        ToastManager.shared.configureToastHistory(isHistoryEnabled: false)

        XCTAssertFalse(history.isHistoryEnabled)
        XCTAssertEqual(history.maxCount, 2000, "第二次调用不应把 maxCount 重置回默认值")
        XCTAssertTrue(history.deferredPersist, "deferredPersist 不应被顺手改回 false")
    }

    func testConfigureToastHistoryDistinguishesNilFromEmptySet() {
        let history = ToastHistoryStore.shared

        ToastManager.shared.configureToastHistory(excludedTypes: [.loading])
        ToastManager.shared.configureToastHistory(maxCount: 10)
        XCTAssertEqual(history.excludedTypes, [.loading], "省略 excludedTypes 应保持原值")

        ToastManager.shared.configureToastHistory(excludedTypes: [])
        XCTAssertTrue(history.excludedTypes.isEmpty, "显式传空集应清空排除列表")
    }

    func testConfigureToastHistoryStillTrimsImmediately() {
        let history = ToastHistoryStore.shared
        ToastManager.shared.configureToastHistory(excludedTypes: [], deferredPersist: true)

        for index in 1...5 {
            history.record(message: "第 \(index) 条")
        }
        XCTAssertEqual(history.records.count, 5)

        ToastManager.shared.configureToastHistory(maxCount: 2)

        XCTAssertEqual(history.records.count, 2, "下调上限后应立即裁剪")
        XCTAssertEqual(history.records.map(\.message), ["第 5 条", "第 4 条"], "应丢掉最旧的")
        history.clearAll()
    }
}
