//
//  StoreManager.swift
//
//  Created by xuehui yang on 2025/10/10.
//

import StoreKit
import SwiftUI

/// A verified StoreKit entitlement that currently grants access.
public struct StoreEntitlementRecord: Sendable {
    public let productID: String
    public let purchaseDate: Date
    public let expirationDate: Date?
    public let ownershipType: StoreKit.Transaction.OwnershipType

    public init(
        productID: String,
        purchaseDate: Date,
        expirationDate: Date? = nil,
        ownershipType: StoreKit.Transaction.OwnershipType
    ) {
        self.productID = productID
        self.purchaseDate = purchaseDate
        self.expirationDate = expirationDate
        self.ownershipType = ownershipType
    }
}

/// A purchase result that distinguishes cancellation and pending approval from failures.
public enum StorePurchaseOutcome: Sendable, Equatable {
    case success(productID: String)
    case pending
    case userCancelled
    case failed(message: String)
}

/*
 StoreKit 购买状态工具类。

 使用方式：

 1. 在调用 App 中定义产品 ID：

    enum AppProductID {
        static let proYearly = "com.yourcompany.yourapp.pro.yearly"
        static let proLifetime = "com.yourcompany.yourapp.pro.lifetime"
        static let tipSmall = "com.yourcompany.yourapp.tip.small"
    }

 2. SwiftUI Environment 推荐直接创建已配置实例：

    @State private var storeManager = StoreManager(
        productIDs: [
            AppProductID.proYearly,
            AppProductID.proLifetime,
            AppProductID.tipSmall
        ],
        proEntitlementProductIDs: [AppProductID.proYearly, AppProductID.proLifetime]
    )

    WindowGroup {
        ContentView()
            .environment(storeManager)
    }

 3. 如果使用单例，可以在 App 启动时配置一次：

    StoreManager.shared.configure(
        productIDs: [
            AppProductID.proYearly,
            AppProductID.proLifetime,
            AppProductID.tipSmall
        ],
        proEntitlementProductIDs: [AppProductID.proYearly, AppProductID.proLifetime]
    )

 4. 购买页中读取产品和购买状态：

    ForEach(storeManager.products) { product in
        let isPurchased = storeManager.isPurchased(product.id)
        Button(isPurchased ? "Purchased" : product.displayPrice) {
            Task {
                await storeManager.purchase(product)
            }
        }
    }

 5. 判断 Pro 状态：

    if storeManager.hasPurchasedPro {
        // 解锁 Pro 功能
    }

 说明：
 - productIDs 和 Pro 权益产品 ID 都由调用 App 提供，工具包不写死任何业务产品。
 - proEntitlementProductIDs 中任一产品拥有有效权益时，hasPurchasedPro 即为 true。
 - 旧版单 proProductID 初始化、配置和属性仍然保留，已有 App 无需立即迁移。
 - init 或 configure 后会自动监听 Transaction.updates，并刷新当前购买状态和商品列表。
 - purchasedProducts 保存每个 productID 当前是否已购买。
 - activeEntitlements 保存 StoreKit 当前验证通过的完整权益快照。
 */
@MainActor
@Observable
public final class StoreManager {
    public static let shared = StoreManager(autoStart: false)

    public var allProductIDs: [String]
    public var proProductID: String?
    public var proEntitlementProductIDs: Set<String>
    public var products: [Product] = []
    public var purchasedProducts: [String: Bool] = [:]
    public var activeEntitlements: [String: StoreEntitlementRecord] = [:]
    public var isLoadingProducts = false
    public var hasLoadedEntitlements = false
    public var purchasingProductID: String?
    public var lastPurchaseOutcome: StorePurchaseOutcome?
    public var lastErrorMessage: String?

    public var hasPurchasedPro: Bool {
        !proEntitlementProductIDs.isDisjoint(with: activeEntitlements.keys)
    }

    // 兼容旧项目里的 storeManager.proProductId 命名。
    public var proProductId: String {
        get { proProductID ?? "" }
        set {
            let oldValue = proProductID
            let resolved = newValue.isEmpty ? nil : newValue
            proProductID = resolved
            if let oldValue {
                proEntitlementProductIDs.remove(oldValue)
            }
            if let resolved {
                proEntitlementProductIDs.insert(resolved)
                appendMissingProductIDs([resolved])
            }
            initializePurchaseFlags()
        }
    }

    @ObservationIgnored
    nonisolated(unsafe) private var transactionUpdatesTask: Task<Void, Never>?

    public init(
        productIDs: [String] = [],
        proProductID: String? = nil,
        autoStart: Bool = true
    ) {
        self.allProductIDs = productIDs
        self.proProductID = proProductID
        self.proEntitlementProductIDs = proProductID.map { Set([$0]) } ?? []
        appendMissingProductIDs(Array(proEntitlementProductIDs))
        initializePurchaseFlags()

        if autoStart {
            start()
        }
    }

    public init(
        productIDs: [String] = [],
        proEntitlementProductIDs: Set<String>,
        autoStart: Bool = true
    ) {
        self.allProductIDs = productIDs
        self.proProductID = proEntitlementProductIDs.first
        self.proEntitlementProductIDs = proEntitlementProductIDs
        appendMissingProductIDs(Array(proEntitlementProductIDs))
        initializePurchaseFlags()

        if autoStart {
            start()
        }
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    public func configure(
        productIDs: [String],
        proProductID: String? = nil,
        autoRefresh: Bool = true
    ) {
        self.allProductIDs = productIDs
        self.proProductID = proProductID
        self.proEntitlementProductIDs = proProductID.map { Set([$0]) } ?? []
        finishConfiguration(autoRefresh: autoRefresh)
    }

    public func configure(
        productIDs: [String],
        proEntitlementProductIDs: Set<String>,
        autoRefresh: Bool = true
    ) {
        self.allProductIDs = productIDs
        self.proProductID = proEntitlementProductIDs.first
        self.proEntitlementProductIDs = proEntitlementProductIDs
        finishConfiguration(autoRefresh: autoRefresh)
    }

    public func start() {
        observeTransactions()

        Task {
            await refresh()
        }
    }

    public func refresh() async {
        await checkAllPurchasedProducts()
        await fetchProducts()
    }

    public func isPurchased(_ productID: String) -> Bool {
        purchasedProducts[productID] == true
    }

    public func product(for productID: String) -> Product? {
        products.first { $0.id == productID }
    }

    public func entitlement(for productID: String) -> StoreEntitlementRecord? {
        activeEntitlements[productID]
    }

    public func observeTransactions() {
        guard transactionUpdatesTask == nil else { return }

        transactionUpdatesTask = Task { [weak self] in
            for await verification in Transaction.updates {
                guard !Task.isCancelled else { return }
                guard let self else { return }

                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    await self.checkAllPurchasedProducts()
                case .unverified(_, let error):
                    self.lastErrorMessage = error.localizedDescription
                }
            }
        }
    }

    public func checkAllPurchasedProducts() async {
        var verifiedEntitlements: [String: StoreEntitlementRecord] = [:]

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard allProductIDs.contains(transaction.productID) else { continue }
            guard transaction.revocationDate == nil else { continue }
            if let expirationDate = transaction.expirationDate, expirationDate <= Date() {
                continue
            }

            verifiedEntitlements[transaction.productID] = StoreEntitlementRecord(
                productID: transaction.productID,
                purchaseDate: transaction.purchaseDate,
                expirationDate: transaction.expirationDate,
                ownershipType: transaction.ownershipType
            )
        }

        applyActiveEntitlements(verifiedEntitlements)
    }

    public func fetchProducts() async {
        guard !allProductIDs.isEmpty else {
            products = []
            return
        }

        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let storeProducts = try await Product.products(for: allProductIDs)
            products = storeProducts.sorted { lhs, rhs in
                productOrder(lhs.id) < productOrder(rhs.id)
            }
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    @discardableResult
    public func purchaseWithOutcome(_ product: Product) async -> StorePurchaseOutcome {
        purchasingProductID = product.id
        defer { purchasingProductID = nil }

        do {
            let result = try await product.purchase()
            let outcome: StorePurchaseOutcome

            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    await checkAllPurchasedProducts()
                    outcome = .success(productID: transaction.productID)
                case .unverified(_, let error):
                    lastErrorMessage = error.localizedDescription
                    outcome = .failed(message: error.localizedDescription)
                }
            case .pending:
                outcome = .pending
            case .userCancelled:
                outcome = .userCancelled
            @unknown default:
                let message = "Unknown purchase result."
                lastErrorMessage = message
                outcome = .failed(message: message)
            }

            lastPurchaseOutcome = outcome
            return outcome
        } catch {
            lastErrorMessage = error.localizedDescription
            let outcome = StorePurchaseOutcome.failed(message: error.localizedDescription)
            lastPurchaseOutcome = outcome
            return outcome
        }
    }

    @discardableResult
    public func purchaseWithOutcome(productID: String) async -> StorePurchaseOutcome {
        if let product = product(for: productID) {
            return await purchaseWithOutcome(product)
        }

        await fetchProducts()
        guard let product = product(for: productID) else {
            let message = "Product not found: \(productID)"
            lastErrorMessage = message
            let outcome = StorePurchaseOutcome.failed(message: message)
            lastPurchaseOutcome = outcome
            return outcome
        }
        return await purchaseWithOutcome(product)
    }

    /// Compatibility API. Prefer `purchaseWithOutcome` for new purchase UIs.
    @discardableResult
    public func purchase(_ product: Product) async -> Bool {
        if case .success = await purchaseWithOutcome(product) {
            return true
        }
        return false
    }

    /// Compatibility API. Prefer `purchaseWithOutcome(productID:)` for new purchase UIs.
    @discardableResult
    public func purchase(productID: String) async -> Bool {
        if case .success = await purchaseWithOutcome(productID: productID) {
            return true
        }
        return false
    }

    func applyActiveEntitlements(_ entitlements: [String: StoreEntitlementRecord]) {
        activeEntitlements = entitlements
        purchasedProducts = Dictionary(
            uniqueKeysWithValues: allProductIDs.map { ($0, entitlements[$0] != nil) }
        )
        hasLoadedEntitlements = true
    }

    private func finishConfiguration(autoRefresh: Bool) {
        appendMissingProductIDs(Array(proEntitlementProductIDs))
        initializePurchaseFlags()
        observeTransactions()

        if autoRefresh {
            Task { await refresh() }
        }
    }

    private func appendMissingProductIDs(_ productIDs: [String]) {
        for productID in productIDs where !allProductIDs.contains(productID) {
            allProductIDs.append(productID)
        }
    }

    private func initializePurchaseFlags() {
        for productID in allProductIDs {
            purchasedProducts[productID] = purchasedProducts[productID] ?? false
        }
    }

    // Internal for unit tests; callers still control presentation order through productIDs.
    func productOrder(_ productID: String) -> Int {
        allProductIDs.firstIndex(of: productID) ?? .max
    }
}
