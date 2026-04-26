//
//  StoreManager.swift
//
//  Created by xuehui yang on 2025/10/10.
//

import SwiftUI
import StoreKit

/*
 StoreKit 购买状态工具类。

 使用方式：

 1. 在调用 App 中定义产品 ID：

    enum AppProductID {
        static let pro = "com.yourcompany.yourapp.pro"
        static let tipSmall = "com.yourcompany.yourapp.tip.small"
    }

 2. SwiftUI Environment 推荐直接创建已配置实例：

    @State private var storeManager = StoreManager(
        productIDs: [
            AppProductID.pro,
            AppProductID.tipSmall
        ],
        proProductID: AppProductID.pro
    )

    WindowGroup {
        ContentView()
            .environment(storeManager)
    }

 3. 如果使用单例，可以在 App 启动时配置一次：

    StoreManager.shared.configure(
        productIDs: [
            AppProductID.pro,
            AppProductID.tipSmall
        ],
        proProductID: AppProductID.pro
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
 - productIDs 和 proProductID 都由调用 App 提供，工具包不写死任何业务产品。
 - proProductID 可以为空；为空时 hasPurchasedPro 永远为 false。
 - init 或 configure 后会自动监听 Transaction.updates，并刷新当前购买状态和商品列表。
 - purchasedProducts 保存每个 productID 当前是否已购买。
 */
@MainActor
@Observable
public final class StoreManager {
    public static let shared = StoreManager(autoStart: false)

    public var allProductIDs: [String]
    public var proProductID: String?
    public var products: [Product] = []
    public var purchasedProducts: [String: Bool] = [:]
    public var isLoadingProducts = false
    public var lastErrorMessage: String?

    public var hasPurchasedPro: Bool {
        guard let proProductID else { return false }
        return isPurchased(proProductID)
    }

    // 兼容旧项目里的 storeManager.proProductId 命名。
    public var proProductId: String {
        get { proProductID ?? "" }
        set {
            proProductID = newValue.isEmpty ? nil : newValue
            if !newValue.isEmpty && !allProductIDs.contains(newValue) {
                allProductIDs.append(newValue)
            }
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
        initializePurchaseFlags()
        observeTransactions()

        if autoRefresh {
            Task {
                await refresh()
            }
        }
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

    public func observeTransactions() {
        guard transactionUpdatesTask == nil else { return }

        transactionUpdatesTask = Task {
            for await verification in Transaction.updates {
                guard !Task.isCancelled else { return }

                switch verification {
                case .verified(let transaction):
                    purchasedProducts[transaction.productID] = true
                    await transaction.finish()
                case .unverified(_, let error):
                    lastErrorMessage = error.localizedDescription
                }
            }
        }
    }

    public func checkAllPurchasedProducts() async {
        initializePurchaseFlags()

        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                purchasedProducts[transaction.productID] = true
            }
        }
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
            products = storeProducts.sorted {
                $0.displayName < $1.displayName
            }
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    purchasedProducts[transaction.productID] = true
                    await transaction.finish()
                    return true
                case .unverified(_, let error):
                    lastErrorMessage = error.localizedDescription
                    return false
                }
            case .pending:
                lastErrorMessage = "Purchase is pending."
                return false
            case .userCancelled:
                return false
            @unknown default:
                lastErrorMessage = "Unknown purchase result."
                return false
            }
        } catch {
            lastErrorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func purchase(productID: String) async -> Bool {
        if let product = product(for: productID) {
            return await purchase(product)
        }

        await fetchProducts()

        guard let product = product(for: productID) else {
            lastErrorMessage = "Product not found: \(productID)"
            return false
        }

        return await purchase(product)
    }

    private func initializePurchaseFlags() {
        for id in allProductIDs {
            purchasedProducts[id] = purchasedProducts[id] ?? false
        }
    }
}
