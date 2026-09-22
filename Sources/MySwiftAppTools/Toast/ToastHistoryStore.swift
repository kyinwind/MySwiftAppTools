//
//  ToastHistoryStore.swift
//  MySwiftAppTools
//
//  Toast 消息历史的持久化存储。
//
//  设计要点：
//  - 存储模型 ToastRecord 与展示模型 ToastItem 分离：ToastItem 含 Image 和闭包，无法序列化。
//  - 枚举用 String 存 rawValue 并做未知值降级，保证将来新增类型不会导致旧数据解码失败。
//  - 三重上限（条数 / 单条长度 / 总字节）防止 UserDefaults 被撑大。
//  - 读写全部走 DefaultsTools，因此 App Group 配置天然生效。
//

import Foundation

// MARK: - 数据模型

/// 可持久化的 Toast 记录。
///
/// 与 `ToastItem` 的区别：`ToastItem` 只用于界面展示，含 `Image` 与闭包，无法序列化；
/// `ToastRecord` 只保留可落盘字段，并补上消息发出时间。
public struct ToastRecord: Codable, Identifiable, Equatable, Sendable {

    public let id: UUID
    public let message: String

    /// `ToastType` 的 rawValue。
    ///
    /// 用 String 存而不是直接存枚举，是为了向前兼容：
    /// 将来新增 `ToastType` case 时，旧版本读到未知值只会降级为 `.normal`，
    /// 而不是让整块数据解码失败。
    public let typeRaw: String
    public let positionRaw: String

    /// 消息发出时间。
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        message: String,
        type: ToastType = .normal,
        position: ToastPosition = .top,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.message = message
        self.typeRaw = type.rawValue
        self.positionRaw = position.rawValue
        self.createdAt = createdAt
    }

    /// 未知类型降级为 `.normal`，保证旧数据永远可读。
    public var type: ToastType {
        ToastType(rawValue: typeRaw) ?? .normal
    }

    /// 未知位置降级为 `.top`。
    public var position: ToastPosition {
        ToastPosition(rawValue: positionRaw) ?? .top
    }
}

// MARK: - 存储

/// Toast 消息历史存储。
///
/// 使用方式：
///
/// ```swift
/// // 默认**不记录**任何历史 —— 必须显式开启才会写入：
/// ToastManager.shared.configureToastHistory(isHistoryEnabled: true)
/// // 开启后需要调整策略时（统一从这个入口改）：
/// ToastManager.shared.configureToastHistory(maxCount: 1000)
/// ```
///
/// - Note: 默认关闭是刻意的。toast 文本常含用户文件路径，落盘属于有副作用的持久化写入，
///   不该由「调用方没写任何相关代码」被动触发。
///
/// - Important: 配置属性对外**只读**，策略变更一律走 `ToastManager.configureToastHistory(...)`。
///   原因是本类的所有实例共用同一个 UserDefaults key，实例级配置会互相打架；
///   包内（测试 / Preview）仍可直接调用 `configure(...)`，那里是「全量重置」语义。
///
/// 消息浏览界面见 `ToastHistoryView` 与 `ToastHistoryWindowController`。
@MainActor
@Observable
public final class ToastHistoryStore {

    public static let shared = ToastHistoryStore()

    /// 存储 key。带包名前缀避免与 App 自身 key 冲突，带版本号便于将来迁移。
    nonisolated public static let storageKey = "MySwiftAppTools.Toast.history.v1"

    // MARK: - 配置
    //
    // 读：public。写：仅包内（internal(set)）。
    // 对外统一走 ToastManager.configureToastHistory(...)，避免出现第二条配置路径
    // 绕过 trim() / 写盘逻辑、以及多实例各设一套策略互相裁剪。

    /// 最多保留条数，超出后从最旧开始丢弃。
    public internal(set) var maxCount = 500

    /// 历史记录总开关。**默认关闭（`false`）** —— 必须显式打开才会写入任何历史。
    ///
    /// 开启方式：`ToastManager.shared.configureToastHistory(isHistoryEnabled: true)`
    public internal(set) var isHistoryEnabled = false

    /// 不记录的类型。默认排除 `.loading`（「处理中…」这类临时状态）。
    public internal(set) var excludedTypes: Set<ToastType> = [.loading]

    /// 单条消息落盘前的最大字符数，超出截断并追加省略号。
    public internal(set) var maxMessageLength = 500

    /// 总字节上限，防止长消息把 UserDefaults 撑大。`0` 表示不限制。
    public internal(set) var maxTotalBytes = 512 * 1024

    /// 高频刷 toast 的 App 可打开：改为只标记脏数据，由 `flush()` 统一写盘。
    public internal(set) var deferredPersist = false

    // MARK: - 数据

    /// 全部历史记录，**新 → 旧**。
    public private(set) var records: [ToastRecord] = []

    /// 是否有未落盘的改动（`deferredPersist` 模式下使用）。
    public private(set) var hasPendingChanges = false

    public init() {
        load()
    }

    // MARK: - 配置入口

    /// 配置入口：**全量重置**语义——未传参数一律回落默认值。
    ///
    /// - Important: 仅包内可用（测试 / Preview 需要「一次调用拿到确定状态」）。
    ///   对外的策略变更请走 `ToastManager.configureToastHistory(...)`，那里是**局部更新**语义，
    ///   省略的参数保持原值，不会把其它项悄悄重置。
    /// - Warning: 全量重置意味着**不传 `isHistoryEnabled` 就会把它关掉**（默认 `false`）。
    ///   包内想记录历史时必须显式写 `isHistoryEnabled: true`。
    internal func configure(
        maxCount: Int = 500,
        isHistoryEnabled: Bool = false,
        excludedTypes: Set<ToastType> = [.loading],
        maxMessageLength: Int = 500,
        maxTotalBytes: Int = 512 * 1024,
        deferredPersist: Bool = false
    ) {
        self.maxCount = max(1, maxCount)
        self.isHistoryEnabled = isHistoryEnabled
        self.excludedTypes = excludedTypes
        self.maxMessageLength = max(1, maxMessageLength)
        self.maxTotalBytes = max(0, maxTotalBytes)
        self.deferredPersist = deferredPersist
        trim()
        persistIfNeeded()
    }

    // MARK: - 写入

    /// 记录一条 toast。`ToastManager.show(...)` 内部会自动调用。
    public func record(_ item: ToastItem) {
        append(
            id: item.id,
            message: item.message,
            type: item.type,
            position: item.position,
            createdAt: item.createdAt
        )
    }

    /// 只记历史、不弹提示的入口。供需要在 UI 之外留痕的调用方使用。
    public func record(message: String, type: ToastType = .normal, position: ToastPosition = .top) {
        append(id: UUID(), message: message, type: type, position: position, createdAt: Date())
    }

    private func append(
        id: UUID,
        message: String,
        type: ToastType,
        position: ToastPosition,
        createdAt: Date
    ) {
        guard isHistoryEnabled else { return }
        guard !excludedTypes.contains(type) else { return }

        let record = ToastRecord(
            id: id,
            message: truncated(message),
            type: type,
            position: position,
            createdAt: createdAt
        )

        records.insert(record, at: 0)
        trim()
        persistIfNeeded()
    }

    // MARK: - 删除

    public func delete(_ record: ToastRecord) {
        delete(id: record.id)
    }

    public func delete(id: UUID) {
        let before = records.count
        records.removeAll { $0.id == id }
        guard records.count != before else { return }
        persistIfNeeded()
    }

    /// 清空全部历史（批量删除）。
    public func clearAll() {
        guard !records.isEmpty else { return }
        records.removeAll()
        persistIfNeeded()
    }

    // MARK: - 读盘 / 写盘

    /// 重新从存储读取。
    ///
    /// App Group 场景下，另一个 App 写入后本界面不会自动刷新，需要调用本方法。
    public func reload() {
        load()
    }

    /// 立即把待写数据落盘（`deferredPersist` 模式下的手动入口）。
    public func flush() {
        persist()
    }

    private func load() {
        guard DefaultsTools.shared.exists(forStringKey: Self.storageKey) else {
            records = []
            return
        }

        guard let decoded = DefaultsTools.shared.codable([ToastRecord].self, forStringKey: Self.storageKey) else {
            // 数据损坏或版本不兼容：不能让它把 App 卡死，清掉坏数据重新开始。
            Log.log("ToastHistory", .error, "Toast 历史解码失败，已清空损坏数据")
            records = []
            DefaultsTools.shared.remove(forStringKey: Self.storageKey)
            return
        }

        // 按时间降序重排，防御脏数据导致的乱序。
        records = decoded.sorted { $0.createdAt > $1.createdAt }
    }

    private func persistIfNeeded() {
        if deferredPersist {
            hasPendingChanges = true
            return
        }
        persist()
    }

    private func persist() {
        DefaultsTools.shared.setCodable(records, forStringKey: Self.storageKey)
        hasPendingChanges = false
    }

    // MARK: - 容量控制

    private func truncated(_ message: String) -> String {
        guard maxMessageLength > 0, message.count > maxMessageLength else { return message }
        return String(message.prefix(maxMessageLength)) + "…"
    }

    /// 三重上限裁剪，按顺序执行：单条截断（写入前已做）→ 条数裁剪 → 总字节兜底。
    private func trim() {
        if maxCount > 0, records.count > maxCount {
            records.removeLast(records.count - maxCount)
        }

        guard maxTotalBytes > 0, !records.isEmpty else { return }

        // 预算是实际上限的 90%，留出估算误差余量，保证真实编码结果不超限。
        let budget = max(1, Int(Double(maxTotalBytes) * 0.9))
        var total = estimatedBytes()
        while !records.isEmpty, total > budget {
            let removed = records.removeLast()
            total -= Self.estimatedBytes(of: removed)
        }
    }

    /// 单条记录的落盘字节估算。
    ///
    /// 实测：固定字段（UUID / 类型 / 位置 / 日期 / JSON 结构符号）约 130 字节，
    /// 中文按 UTF-8 每字符 3 字节。
    private static func estimatedBytes(of record: ToastRecord) -> Int {
        130 + record.message.utf8.count
    }

    private func estimatedBytes() -> Int {
        records.reduce(0) { $0 + Self.estimatedBytes(of: $1) }
    }
}
