import Foundation
import SwiftUI

/*
 这个工具类是为了保存目录权限的 bookmark而构造的保存结构
 */
public enum MyDirectoryType: String, Codable, Sendable {
    case normal    //正常维护的目标目录，都有label
    case noLabel    //临时保存的，没有label
    case history    //临时保存的历史记录，自动生成的label
    public var title: String {
        switch self {
        case .normal:
            return "MyDirectoryType.normal".toNSLocalizedString
        case .noLabel:
            return "MyDirectoryType.nolabel".toNSLocalizedString
        case .history:
            return "MyDirectoryType.history".toNSLocalizedString
        }
    }
}

//定义目录结构体
public struct MyDirectory: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var url: URL
    public var bookmarkData: Data?
    /// 可选业务元数据（比如 Backup 显示名）
    public var label: String?
    public var type: MyDirectoryType
    public var createDate:Date
    
    //这三个属性，用于保存历史数据
    public var useCount: Int?       //用过的数量
    public var recentUseCount: Int?   //最近用过的数量
    public var lastUsedAt: Date?        //最近用过的时间
    
    public init(url: URL, bookmarkData: Data? = nil, label: String? = nil, type: MyDirectoryType) {
        self.id = UUID()
        self.url = url
        self.bookmarkData = bookmarkData
        self.label = label
        self.type = type
        self.createDate = Date.now
        
        self.useCount = nil
        self.recentUseCount = nil
        self.lastUsedAt = nil
    }
    public init(url: URL, bookmarkData: Data? = nil, label: String? = nil, type: MyDirectoryType,useCount:Int,recentUseCount:Int,lastUsedAt:Date) {
        self.id = UUID()
        self.url = url
        self.bookmarkData = bookmarkData
        self.label = label
        self.type = type
        self.createDate = Date.now
        
        self.useCount = useCount
        self.recentUseCount = recentUseCount
        self.lastUsedAt = lastUsedAt
    }
    // Hashable
    public static func == (lhs: MyDirectory, rhs: MyDirectory) -> Bool {
        lhs.url.normalized.path == rhs.url.normalized.path
    }

    // 安全书签解析
    public func getSecurityScopedURL() -> (URL?, Bool) {
        guard let data = bookmarkData else {
            return (url, false)
        }

        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                NSLog("⚠️ 书签已过期，建议重新添加目录")
            }

            return (url, true)
        } catch {
            NSLog("❌ 无法解析书签数据: \(error)")
            return (nil, false)
        }
    }
}


public protocol DirectoryStore {
    static var key: String { get }
    static func load() -> [MyDirectory]
    static func save(_ list: [MyDirectory])
    static func remove(_ url: URL)
}

public final class DirectoryManager: DirectoryStore {

    nonisolated(unsafe) private static var defaults: UserDefaults = .standard

    public static let key = "AuthorizedDirectories"

    /// 配置目录授权书签的存储空间。
    ///
    /// 默认使用 `.standard`。如果 App 有扩展，并且需要在主 App 与扩展之间共享
    /// security-scoped bookmark，请在主 App 和扩展启动时都传入同一个 App Group：
    ///
    /// ```swift
    /// DirectoryManager.configure(appGroupID: "group.com.yourcompany.yourapp")
    /// ```
    @discardableResult
    public static func configure(appGroupID: String) -> Bool {
        guard let userDefaults = UserDefaults(suiteName: appGroupID) else {
            return false
        }

        configure(userDefaults: userDefaults)
        return true
    }

    /// 使用调用方提供的 `UserDefaults` 存储目录授权书签。
    ///
    /// 适合测试，或调用方已经自己创建好 App Group `UserDefaults` 的场景。
    public static func configure(userDefaults: UserDefaults) {
        defaults = userDefaults
    }

    /// 恢复到默认的 `.standard` 存储空间。
    public static func resetStorageToStandard() {
        defaults = .standard
    }

    public static func load() -> [MyDirectory] {
        guard let data = defaults.data(forKey: key) else { return [] }
        let all = (try? JSONDecoder().decode([MyDirectory].self, from: data)) ?? []
        let sort = all.sorted {
            //按照类型、时间排序
            if $0.type.rawValue == $1.type.rawValue {
                return $0.createDate > $1.createDate
            }
            return $0.type.rawValue > $1.type.rawValue
        }
        
        return sort
    }
    
    public static func loadByUrl(url: URL) -> MyDirectory? {
        guard let data = defaults.data(forKey: key),
              let dirs = try? JSONDecoder().decode([MyDirectory].self, from: data)
        else {
            return nil
        }

        let targetPath = url.standardizedFileURL.path

        return dirs.first {
            $0.url.standardizedFileURL.path == targetPath
        }
    }
    /// 用户手工录入的目录，也就是不是历史目录，也不是临时目录
    public static func loadNormalDirectories() -> [MyDirectory] {
        load().filter { $0.type == .normal }
            .sorted {
                if $0.type.rawValue == $1.type.rawValue {
                    return $0.createDate > $1.createDate
                }
                return $0.type.rawValue > $1.type.rawValue
            }
    }
    
    public static func save(_ list: [MyDirectory]) {
        if list.isEmpty {
            defaults.removeObject(forKey: key)
            return
        }
        if let data = try? JSONEncoder().encode(list) {
            defaults.set(data, forKey: key)
        }
    }

    public static func remove(_ delUrl: URL) {
        var list = load()
        list.removeAll { $0.url.normalized.path == delUrl.normalized.path }
        save(list)
    }
    public static func removeInType(_ delUrl: URL,type:MyDirectoryType) {
        var list = load()
        list.removeAll { $0.url.normalized.path == delUrl.normalized.path && $0.type == type}
        save(list)
    }
    public static func appendAndSave(_ new: MyDirectory){
        var list = load()
        list.append(new)
        save(list)
    }
    
    /// load 历史记录
    public static func loadHistory() -> [MyDirectory] {
        load().filter { $0.type == .history || $0.type == .noLabel }
            .sorted { if $0.type.rawValue == $1.type.rawValue {
                return $0.createDate > $1.createDate
            }
            return $0.type.rawValue > $1.type.rawValue }
            //.sorted {$0.label!.localizedCaseInsensitiveCompare($1.label!) == .orderedAscending}
    }
    
    public static func saveHistory(_ list: [MyDirectory]) {
        var alllist = load()
        
        alllist.removeAll(where: {$0.type == .history  || $0.type == .noLabel})
        alllist += list
        save(alllist)
        
        return
    }
}

public extension URL {

    /// 判断 self 是否在 base 目录下面（含 base 本身可加参数控制）
    func isIn(in base: URL, includeBase: Bool = true) -> Bool {

        let target = self.resolvingSymlinksInPath().standardizedFileURL
        let baseURL = base.resolvingSymlinksInPath().standardizedFileURL

        let targetPath = target.path
        let basePath = baseURL.path

        if includeBase && targetPath == basePath {
            return true
        }

        return targetPath.hasPrefix(basePath + "/")
    }

    var normalized: URL {
        self
            .resolvingSymlinksInPath()
            .standardizedFileURL
    }

    var isDirectory: Bool {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: self.path, isDirectory: &isDir)
        return isDir.boolValue
    }
}
