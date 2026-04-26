//
//  KeychainTools.swift
//  TTSMate
//
//  Created by yangxuehui on 2026/01/02.
//

import Foundation
import Security
enum KeychainAccount {
    static let azureApiKey = "AZURE_SPEECH_KEY"
    static let azureRegion = "AZURE_SERVICE_REGION"
    static let openAIApiKey = "openai.apiKey"
}

/// Keychain 工具封装
/// - 设计目标：
///   1. 底层支持完整参数（service + account）
///   2. 上层提供 App 默认 service 的便捷方法
enum KeychainTools {

    // MARK: - Default Service (App Level)

    /// App 级默认 service
    /// 所有不特殊指定的 Keychain 数据都会存到这里
    private static let defaultService = "TTSMate"

    // MARK: - Core (Full Params)

    /// 保存数据（完整参数）
    @discardableResult
    static func save(
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
    static func load(
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
    static func delete(
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
    static func save(
        _ value: String,
        account: String
    ) -> Bool {
        save(value, service: defaultService, account: account)
    }

    /// 读取数据（使用 App 默认 service）
    static func load(
        account: String
    ) -> String? {
        load(service: defaultService, account: account)
    }

    /// 删除数据（使用 App 默认 service）
    @discardableResult
    static func delete(
        account: String
    ) -> Bool {
        delete(service: defaultService, account: account)
    }

    // MARK: - Sub Service Support (Optional)

    /// 保存数据（App.serviceSuffix）
    /// 例如：TTSMate.Azure / TTSMate.OpenAI
    @discardableResult
    static func save(
        _ value: String,
        serviceSuffix: String,
        account: String
    ) -> Bool {
        let service = "\(defaultService).\(serviceSuffix)"
        return save(value, service: service, account: account)
    }

    /// 读取数据（App.serviceSuffix）
    static func load(
        serviceSuffix: String,
        account: String
    ) -> String? {
        let service = "\(defaultService).\(serviceSuffix)"
        return load(service: service, account: account)
    }

    /// 删除数据（App.serviceSuffix）
    @discardableResult
    static func delete(
        serviceSuffix: String,
        account: String
    ) -> Bool {
        let service = "\(defaultService).\(serviceSuffix)"
        return delete(service: service, account: account)
    }
}
