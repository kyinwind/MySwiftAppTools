//
//  ProGatekeeper.swift
//
//  Created by yangxuehui on 2026/2/10.
//

import Foundation

/*
 DefaultsTools 保存免费用户的使用次数和每日重置日期。
 调用方负责定义 feature、购买状态和购买入口。

 使用方式：

 1. 在调用 App 中定义自己的 Pro 功能枚举：

    enum AppProFeature: String {
        case privacyOCR
        case privacyAIRepair
        case privacyBatch
    }

 2. 在 App 启动时配置一次：

    ProGatekeeper.configure(
        freeLimits: [
            AppProFeature.privacyOCR: 10,
            AppProFeature.privacyAIRepair: 5,
            AppProFeature.privacyBatch: 0
        ],
        keyPrefix: "YourApp.ProGatekeeper",
        hasPurchasedPro: {
            AppState.shared.hasPurchasedPro
        },
        presentPurchase: {
            // 打开你的购买页、设置页或订阅弹窗
        }
    )

 3. 使用功能前检查权限：

    if await ProGatekeeper.check(AppProFeature.privacyOCR) {
        // 执行功能
    }

 4. 查询免费额度剩余次数：

    let remaining = ProGatekeeper.remaining(AppProFeature.privacyOCR)

 说明：
 - freeLimits 中没有声明的 feature，会被视为 Pro-only，免费用户不允许使用。
 - freeLimits 的值为 0 时，表示免费用户完全不能使用该功能。
 - Pro 用户由 hasPurchasedPro 返回 true 后直接放行，不消耗免费次数。
 - keyPrefix 用于隔离不同 App 或不同功能组在 UserDefaults 中保存的计数。
 */
@MainActor
public enum ProGatekeeper {
    private static var hasPurchasedPro: () -> Bool = { false }
    private static var presentPurchase: () -> Void = {}
    public static var freeLimits: [String: Int] = [:]
    private static var keyPrefix = "ProGatekeeper"

    public static func configure(
        freeLimits: [String: Int],
        keyPrefix: String = "ProGatekeeper",
        hasPurchasedPro: @escaping () -> Bool,
        presentPurchase: @escaping () -> Void
    ) {
        self.freeLimits = freeLimits
        self.keyPrefix = keyPrefix
        self.hasPurchasedPro = hasPurchasedPro
        self.presentPurchase = presentPurchase
    }

    public static func configure<Feature>(
        freeLimits: [Feature: Int],
        keyPrefix: String = "ProGatekeeper",
        hasPurchasedPro: @escaping () -> Bool,
        presentPurchase: @escaping () -> Void
    ) where Feature: Hashable & RawRepresentable, Feature.RawValue == String {
        configure(
            freeLimits: Dictionary(uniqueKeysWithValues: freeLimits.map { ($0.key.rawValue, $0.value) }),
            keyPrefix: keyPrefix,
            hasPurchasedPro: hasPurchasedPro,
            presentPurchase: presentPurchase
        )
    }

    public static func check(_ feature: String) async -> Bool {
        if allow(feature) {
            consume(feature)
            return true
        }

        presentPurchase()
        return false
    }

    public static func check<Feature>(_ feature: Feature) async -> Bool where Feature: RawRepresentable, Feature.RawValue == String {
        await check(feature.rawValue)
    }

    public static func allow(_ feature: String) -> Bool {
        if hasPurchasedPro() {
            return true
        }

        guard let limit = freeLimits[feature] else {
            return false
        }

        resetIfNeeded()

        return currentCount(for: feature) < limit
    }

    public static func allow<Feature>(_ feature: Feature) -> Bool where Feature: RawRepresentable, Feature.RawValue == String {
        allow(feature.rawValue)
    }

    public static func remaining(_ feature: String) -> Int? {
        guard let limit = freeLimits[feature] else {
            return nil
        }

        if hasPurchasedPro() {
            return nil
        }

        resetIfNeeded()

        return max(0, limit - currentCount(for: feature))
    }

    public static func remaining<Feature>(_ feature: Feature) -> Int? where Feature: RawRepresentable, Feature.RawValue == String {
        remaining(feature.rawValue)
    }

    public static func debugReset() {
        for feature in freeLimits.keys {
            DefaultsTools.shared.set(0, for: usageKey(for: feature))
        }
        DefaultsTools.shared.set(Calendar.current.startOfDay(for: Date()), for: lastResetDateKey)
    }

    private static func consume(_ feature: String) {
        guard !hasPurchasedPro() else { return }
        guard freeLimits[feature] != nil else { return }

        resetIfNeeded()

        let key = usageKey(for: feature)
        let current = DefaultsTools.shared.int(key) ?? 0
        DefaultsTools.shared.set(current + 1, for: key)
    }

    private static func currentCount(for feature: String) -> Int {
        DefaultsTools.shared.int(usageKey(for: feature)) ?? 0
    }

    private static func resetIfNeeded() {
        let today = Calendar.current.startOfDay(for: Date())
        let last = DefaultsTools.shared.value(for: lastResetDateKey) as Date? ?? .distantPast

        guard !Calendar.current.isDate(today, inSameDayAs: last) else {
            return
        }

        for feature in freeLimits.keys {
            DefaultsTools.shared.set(0, for: usageKey(for: feature))
        }

        DefaultsTools.shared.set(today, for: lastResetDateKey)
    }

    private static var lastResetDateKey: DefaultsTools.Key {
        DefaultsTools.Key(rawValue: "\(keyPrefix).lastResetDate")
    }

    private static func usageKey(for feature: String) -> DefaultsTools.Key {
        DefaultsTools.Key(rawValue: "\(keyPrefix).usage.\(feature)")
    }
}
