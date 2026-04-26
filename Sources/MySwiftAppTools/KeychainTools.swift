//
//  KeychainTools.swift
//  TTSMate
//
//  Created by yangxuehui on 2026/01/02.
//

import Foundation
import Security

/// Keychain 工具封装
/// - 设计目标：
///   1. 底层支持完整参数（service + account）
///   2. 上层提供 App 默认 service 的便捷方法
///   App 里可以这样写：
/// 使用方法：
//enum AppKeychainAccount: String {
//    case azureApiKey = "AZURE_SPEECH_KEY"
//    case azureRegion = "AZURE_SERVICE_REGION"
//    case openAIApiKey = "openai.apiKey"
//}
//启动时配置一次：
//
//KeychainTools.configure(defaultService: "RightClickMate")
//使用时：
//
//KeychainTools.save("sk-xxx", account: AppKeychainAccount.openAIApiKey)
//
//let key = KeychainTools.load(account: AppKeychainAccount.openAIApiKey)
//
//KeychainTools.delete(account: AppKeychainAccount.openAIApiKey)
public enum KeychainTools {

    // MARK: - Default Service (App Level)

    /// App 级默认 service
    /// 所有不特殊指定的 Keychain 数据都会存到这里
    nonisolated(unsafe) private static var defaultService = Bundle.main.bundleIdentifier ?? "MySwiftAppTools"

    public static func configure(defaultService: String) {
        guard !defaultService.isEmpty else { return }
        self.defaultService = defaultService
    }

    // MARK: - Core (Full Params)

    /// 保存数据（完整参数）
    @discardableResult
    public static func save(
        _ value: String,
        service: String,
        account: String
    ) -> Bool {

        guard let data = value.data(using: .utf8) else {
            return false
        }

        // 先删再存，避免重复
        delete(service: service, account: account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// 读取数据（完整参数）
    public static func load(
        service: String,
        account: String
    ) -> String? {

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard
            status == errSecSuccess,
            let data = item as? Data,
            let value = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        return value
    }

    /// 删除数据（完整参数）
    @discardableResult
    public static func delete(
        service: String,
        account: String
    ) -> Bool {

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - App Default Service (Convenience)

    /// 保存数据（使用 App 默认 service）
    @discardableResult
    public static func save(
        _ value: String,
        account: String
    ) -> Bool {
        save(value, service: defaultService, account: account)
    }

    @discardableResult
    public static func save<Account: RawRepresentable>(
        _ value: String,
        account: Account
    ) -> Bool where Account.RawValue == String {
        save(value, account: account.rawValue)
    }

    /// 读取数据（使用 App 默认 service）
    public static func load(
        account: String
    ) -> String? {
        load(service: defaultService, account: account)
    }

    public static func load<Account: RawRepresentable>(
        account: Account
    ) -> String? where Account.RawValue == String {
        load(account: account.rawValue)
    }

    /// 删除数据（使用 App 默认 service）
    @discardableResult
    public static func delete(
        account: String
    ) -> Bool {
        delete(service: defaultService, account: account)
    }

    @discardableResult
    public static func delete<Account: RawRepresentable>(
        account: Account
    ) -> Bool where Account.RawValue == String {
        delete(account: account.rawValue)
    }

    // MARK: - Sub Service Support (Optional)

    /// 保存数据（App.serviceSuffix）
    /// 例如：TTSMate.Azure / TTSMate.OpenAI
    @discardableResult
    public static func save(
        _ value: String,
        serviceSuffix: String,
        account: String
    ) -> Bool {
        let service = "\(defaultService).\(serviceSuffix)"
        return save(value, service: service, account: account)
    }

    @discardableResult
    public static func save<Account: RawRepresentable>(
        _ value: String,
        serviceSuffix: String,
        account: Account
    ) -> Bool where Account.RawValue == String {
        save(value, serviceSuffix: serviceSuffix, account: account.rawValue)
    }

    /// 读取数据（App.serviceSuffix）
    public static func load(
        serviceSuffix: String,
        account: String
    ) -> String? {
        let service = "\(defaultService).\(serviceSuffix)"
        return load(service: service, account: account)
    }

    public static func load<Account: RawRepresentable>(
        serviceSuffix: String,
        account: Account
    ) -> String? where Account.RawValue == String {
        load(serviceSuffix: serviceSuffix, account: account.rawValue)
    }

    /// 删除数据（App.serviceSuffix）
    @discardableResult
    public static func delete(
        serviceSuffix: String,
        account: String
    ) -> Bool {
        let service = "\(defaultService).\(serviceSuffix)"
        return delete(service: service, account: account)
    }

    @discardableResult
    public static func delete<Account: RawRepresentable>(
        serviceSuffix: String,
        account: Account
    ) -> Bool where Account.RawValue == String {
        delete(serviceSuffix: serviceSuffix, account: account.rawValue)
    }
}
