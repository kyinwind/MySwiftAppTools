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
        ud.set(value, forKey: key.rawValue)
    }

    public func value<T>(for key: Key) -> T? {
        ud.value(forKey: key.rawValue) as? T
    }

    public func remove(_ key: Key) {
        ud.removeObject(forKey: key.rawValue)
    }

    public func exists(_ key: Key) -> Bool {
        ud.object(forKey: key.rawValue) != nil
    }

    // MARK: - Bool / Int / Double / String 快捷

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

    public func string(_ key: Key) -> String? {
        ud.string(forKey: key.rawValue)
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
}
public extension DefaultsTools {

    // MARK: - 直接支持 string key

    func set<T>(_ value: T?, forStringKey key: String) {
        ud.set(value, forKey: key)
    }

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

    func string(forStringKey key: String) -> String? {
        return ud.string(forKey: key)
    }
}

// MARK: - Codable 支持，可以保存结构体
public extension DefaultsTools {
    /// 保存 Codable 对象
    func setCodable<T: Codable>(_ value: T, forStringKey key: String) {
        do {
            let data = try JSONEncoder().encode(value)
            ud.set(data, forKey: key)
        } catch {
            print("DefaultsTools 保存 Codable 失败：\(error)")
        }
    }

    /// 读取 Codable 对象
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
