//
//  UserDefaults.swift
//
//
//  Created by yangxuehui on 2026/2/6.
//

import Foundation

/// UserDefaults 统一访问工具
public struct DefaultsTools: @unchecked Sendable {
    // MARK: - App Group ID
    nonisolated(unsafe) public static var appGroupID = "group.com.michaeldev"

    // MARK: - 实例

    private let ud: UserDefaults

    private init(userDefaults: UserDefaults) {
        self.ud = userDefaults
    }
    
    //在项目 app 启动时，如果有 groupid，可以进行配置，如果没有则不用管，DefaultsTools会默认使用 app 本身的standard配置
    public static func configure(appGroupID: String) {
        self.appGroupID = appGroupID
    }
    // MARK: - 工厂

    //static let standard = DefaultsTools(userDefaults: .standard)

    public static var group: DefaultsTools {
        DefaultsTools(userDefaults: UserDefaults(suiteName: appGroupID) ?? .standard)
    }
    
    /// 自动选择（推荐）调用的入口
    public static var shared: DefaultsTools {
        if let groupUD = UserDefaults(suiteName: appGroupID) {
            return DefaultsTools(userDefaults: groupUD)
        } else {
            return DefaultsTools(userDefaults: .standard)
        }
    }

    // MARK: - 基础读写（强类型）

    public func set<T>(_ value: T?, for key: Key) {
        guard let value else {
            remove(key)
            return
        }
        ud.set(value, forKey: key.rawValue)
    }

    public func set(_ value: Bool?, for key: Key) { setPropertyListValue(value, for: key.rawValue) }
    public func set(_ value: Int?, for key: Key) { setPropertyListValue(value, for: key.rawValue) }
    public func set(_ value: Double?, for key: Key) { setPropertyListValue(value, for: key.rawValue) }
    public func set(_ value: Float?, for key: Key) { setPropertyListValue(value, for: key.rawValue) }
    public func set(_ value: String?, for key: Key) { setPropertyListValue(value, for: key.rawValue) }
    public func set(_ value: Data?, for key: Key) { setPropertyListValue(value, for: key.rawValue) }
    public func set(_ value: Date?, for key: Key) { setPropertyListValue(value, for: key.rawValue) }

    public func set(_ value: URL?, for key: Key) {
        guard let value else {
            remove(key)
            return
        }
        ud.set(value, forKey: key.rawValue)
    }

    public func set(_ value: [String]?, for key: Key) { setPropertyListValue(value, for: key.rawValue) }
    public func set(_ value: [Any]?, for key: Key) { setPropertyListValue(value, for: key.rawValue) }
    public func set(_ value: [String: Any]?, for key: Key) { setPropertyListValue(value, for: key.rawValue) }

    public func value<T>(for key: Key) -> T? {
        ud.value(forKey: key.rawValue) as? T
    }

    public func remove(_ key: Key) {
        ud.removeObject(forKey: key.rawValue)
    }

    public func exists(_ key: Key) -> Bool {
        ud.object(forKey: key.rawValue) != nil
    }

    // MARK: - Bool / Int / Double / Float / String / Data / Date / URL 快捷

    public func bool(_ key: Key) -> Bool? {
        guard ud.object(forKey: key.rawValue) != nil else { return nil }
        return ud.bool(forKey: key.rawValue)
    }

    public func int(_ key: Key) -> Int? {
        guard ud.object(forKey: key.rawValue) != nil else { return nil }
        return ud.integer(forKey: key.rawValue)
    }

    public func double(_ key: Key) -> Double? {
        guard ud.object(forKey: key.rawValue) != nil else { return nil }
        return ud.double(forKey: key.rawValue)
    }

    public func float(_ key: Key) -> Float? {
        guard ud.object(forKey: key.rawValue) != nil else { return nil }
        return ud.float(forKey: key.rawValue)
    }

    public func string(_ key: Key) -> String? {
        ud.string(forKey: key.rawValue)
    }

    public func data(_ key: Key) -> Data? {
        ud.data(forKey: key.rawValue)
    }

    public func date(_ key: Key) -> Date? {
        ud.object(forKey: key.rawValue) as? Date
    }

    public func url(_ key: Key) -> URL? {
        ud.url(forKey: key.rawValue)
    }

    public func stringArray(_ key: Key) -> [String]? {
        ud.stringArray(forKey: key.rawValue)
    }

    public func array<T>(_ key: Key, as type: T.Type = T.self) -> [T]? {
        ud.array(forKey: key.rawValue) as? [T]
    }

    public func dictionary(_ key: Key) -> [String: Any]? {
        ud.dictionary(forKey: key.rawValue)
    }

    public func dictionary<T>(_ key: Key, as type: T.Type = T.self) -> [String: T]? {
        ud.dictionary(forKey: key.rawValue) as? [String: T]
    }
    public struct Key: RawRepresentable, Hashable, ExpressibleByStringLiteral {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public init(stringLiteral value: String) {
            self.rawValue = value
        }

    }

    private func setPropertyListValue(_ value: Any?, for key: String) {
        guard let value else {
            ud.removeObject(forKey: key)
            return
        }
        ud.set(value, forKey: key)
    }
}
public extension DefaultsTools {

    // MARK: - 直接支持 string key

    func set<T>(_ value: T?, forStringKey key: String) {
        guard let value else {
            remove(forStringKey: key)
            return
        }
        ud.set(value, forKey: key)
    }

    func set(_ value: Bool?, forStringKey key: String) { setPropertyListValue(value, for: key) }
    func set(_ value: Int?, forStringKey key: String) { setPropertyListValue(value, for: key) }
    func set(_ value: Double?, forStringKey key: String) { setPropertyListValue(value, for: key) }
    func set(_ value: Float?, forStringKey key: String) { setPropertyListValue(value, for: key) }
    func set(_ value: String?, forStringKey key: String) { setPropertyListValue(value, for: key) }
    func set(_ value: Data?, forStringKey key: String) { setPropertyListValue(value, for: key) }
    func set(_ value: Date?, forStringKey key: String) { setPropertyListValue(value, for: key) }

    func set(_ value: URL?, forStringKey key: String) {
        guard let value else {
            remove(forStringKey: key)
            return
        }
        ud.set(value, forKey: key)
    }

    func set(_ value: [String]?, forStringKey key: String) { setPropertyListValue(value, for: key) }
    func set(_ value: [Any]?, forStringKey key: String) { setPropertyListValue(value, for: key) }
    func set(_ value: [String: Any]?, forStringKey key: String) { setPropertyListValue(value, for: key) }

    func value<T>(forStringKey key: String) -> T? {
        ud.value(forKey: key) as? T
    }

    func remove(forStringKey key: String) {
        ud.removeObject(forKey: key)
    }

    func exists(forStringKey key: String) -> Bool {
        ud.object(forKey: key) != nil
    }

    func bool(forStringKey key: String) -> Bool? {
        guard exists(forStringKey: key) else { return nil }
        return ud.bool(forKey: key)
    }

    func int(forStringKey key: String) -> Int? {
        guard exists(forStringKey: key) else { return nil }
        return ud.integer(forKey: key)
    }

    func double(forStringKey key: String) -> Double? {
        guard exists(forStringKey: key) else { return nil }
        if let number = ud.object(forKey: key) as? NSNumber {
            return number.doubleValue
        }
        if let text = ud.string(forKey: key) {
            return Double(text)
        }
        return nil
    }

    func float(forStringKey key: String) -> Float? {
        guard exists(forStringKey: key) else { return nil }
        if let number = ud.object(forKey: key) as? NSNumber {
            return number.floatValue
        }
        if let text = ud.string(forKey: key) {
            return Float(text)
        }
        return nil
    }

    func string(forStringKey key: String) -> String? {
        return ud.string(forKey: key)
    }

    func data(forStringKey key: String) -> Data? {
        ud.data(forKey: key)
    }

    func date(forStringKey key: String) -> Date? {
        ud.object(forKey: key) as? Date
    }

    func url(forStringKey key: String) -> URL? {
        ud.url(forKey: key)
    }

    func stringArray(forStringKey key: String) -> [String]? {
        ud.stringArray(forKey: key)
    }

    func array<T>(forStringKey key: String, as type: T.Type = T.self) -> [T]? {
        ud.array(forKey: key) as? [T]
    }

    func dictionary(forStringKey key: String) -> [String: Any]? {
        ud.dictionary(forKey: key)
    }

    func dictionary<T>(forStringKey key: String, as type: T.Type = T.self) -> [String: T]? {
        ud.dictionary(forKey: key) as? [String: T]
    }
}

// MARK: - Codable 支持，可以保存结构体
public extension DefaultsTools {
    /// 保存 Codable 对象
    func setCodable<T: Codable>(_ value: T, for key: Key) {
        setCodable(value, forStringKey: key.rawValue)
    }

    func setCodable<T: Codable>(_ value: T, forStringKey key: String) {
        do {
            let data = try JSONEncoder().encode(value)
            ud.set(data, forKey: key)
        } catch {
            print("DefaultsTools 保存 Codable 失败：\(error)")
        }
    }

    /// 读取 Codable 对象
    func codable<T: Codable>(_ type: T.Type, for key: Key) -> T? {
        codable(type, forStringKey: key.rawValue)
    }

    func codable<T: Codable>(_ type: T.Type, forStringKey key: String) -> T? {
        guard let data = ud.data(forKey: key) else { return nil }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            print("DefaultsTools 读取 Codable 失败：\(error)")
            return nil
        }
    }
}
