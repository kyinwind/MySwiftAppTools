//
//  UserDefaults.swift
//
//
//  Created by yangxuehui on 2026/2/6.
//

import Foundation

/// UserDefaults 统一访问工具
struct DefaultsTools: @unchecked Sendable {
    // MARK: - App Group ID
    nonisolated(unsafe) static var appGroupID = "group.com.michaeldev"

    // MARK: - 实例

    private let ud: UserDefaults

    private init(userDefaults: UserDefaults) {
        self.ud = userDefaults
    }
    
    //在项目 app 启动时，如果有 groupid，可以进行配置，如果没有则不用管，DefaultsTools会默认使用 app 本身的standard配置
    static func configure(appGroupID: String) {
        self.appGroupID = appGroupID
    }
    // MARK: - 工厂

    //static let standard = DefaultsTools(userDefaults: .standard)

    static let group = DefaultsTools(
        userDefaults: UserDefaults(suiteName: appGroupID) ?? .standard
    )
    
    /// 自动选择（推荐）调用的入口
    static var shared: DefaultsTools {
        if let groupUD = UserDefaults(suiteName: appGroupID) {
            return DefaultsTools(userDefaults: groupUD)
        } else {
            return DefaultsTools(userDefaults: .standard)
        }
    }

    // MARK: - 基础读写（强类型）

    func set<T>(_ value: T?, for key: Key) {
        ud.set(value, forKey: key.rawValue)
    }

    func value<T>(for key: Key) -> T? {
        ud.value(forKey: key.rawValue) as? T
    }

    func remove(_ key: Key) {
        ud.removeObject(forKey: key.rawValue)
    }

    func exists(_ key: Key) -> Bool {
        ud.object(forKey: key.rawValue) != nil
    }

    // MARK: - Bool / Int / Double / String 快捷

    func bool(_ key: Key) -> Bool? {
        guard ud.object(forKey: key.rawValue) != nil else { return nil }
        return ud.bool(forKey: key.rawValue)
    }

    func int(_ key: Key) -> Int? {
        guard ud.object(forKey: key.rawValue) != nil else { return nil }
        return ud.integer(forKey: key.rawValue)
    }

    func double(_ key: Key) -> Double? {
        guard ud.object(forKey: key.rawValue) != nil else { return nil }
        return ud.double(forKey: key.rawValue)
    }

    func string(_ key: Key) -> String? {
        ud.string(forKey: key.rawValue)
    }
    struct Key: RawRepresentable, Hashable, ExpressibleByStringLiteral {
        let rawValue: String

        init(rawValue: String) {
            self.rawValue = rawValue
        }

        init(stringLiteral value: String) {
            self.rawValue = value
        }

    }
}
extension DefaultsTools {

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
