//
//  StoreManager.swift
//  DayDayUp
//
//  Created by xuehui yang on 2025/10/10.
//

import SwiftUI
import StoreKit

@MainActor
@Observable
class StoreManager {
    static var shared:StoreManager = StoreManager()
    let proProductId = "com.michaeldev.RightClickMate.Pro"
    var allProductIDs:[String] = []  //所有产品 id 的字符串数组
    var products: [Product] = []  //根据产品 id 取出的对象数组
    var purchasedProducts: [String: Bool] = [:]  // ✅ 保存所有产品的购买状态
    //var showProductPurchase: Bool = false  //是否显示购买窗口
    var hasPurchasedPro : Bool = false
    //var hasPurchasedProductDialogMode : Bool = false
    init() {
        allProductIDs = [
            proProductId
        ]
        // 1️⃣ 启动时检查一次所有购买状态
        Task {
            await self.checkAllPurchasedProducts()
            await fetchProducts()
            //同步标志
            statusSync()
        }
        // 2️⃣ 启动交易监听，实时更新购买变化
        observeTransactions()
    }
    //根据产品购买的信息同步标志
    func statusSync(){
        hasPurchasedPro = purchasedProducts[proProductId] ?? false
    }
    func observeTransactions() {
        Task {
            for await verification in Transaction.updates {
                switch verification {
                case .verified(let transaction):
                    print("Transaction verified: \(transaction)")
                    purchasedProducts[transaction.productID] = true  // ✅ 更新状态
                    await transaction.finish()
                    //同步标志
                    statusSync()
                case .unverified(_, let error):
                    print("Unverified transaction: \(error)")
                }
            }
        }
    }

    // ✅ 检查当前用户已购买的所有产品
    func checkAllPurchasedProducts() async {
        // ✅ 1. 先初始化所有支持的产品为 false

        for id in allProductIDs {
            purchasedProducts[id] = false
        }

        // ✅ 2. 再更新已购买的产品为 true
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                purchasedProducts[transaction.productID] = true
                print("✅ 已购买产品: \(transaction.productID)")
                //同步标志
                statusSync()
            }
        }

        print("📦 当前购买状态: \(purchasedProducts)")
    }

    // ✅ 获取上架可售产品，放到对象数组products
    func fetchProducts() async {
        do {
            let storeProducts = try await Product.products(for: allProductIDs)
            await MainActor.run {
                self.products = storeProducts.sorted {
                    $0.displayName < $1.displayName
                }
            }
        } catch {
            print("Failed to load products: \(error)")
        }
    }

    // ✅ 购买指定产品
    func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    print("✅ 购买成功: \(transaction.productID)")
                    purchasedProducts[transaction.productID] = true  // ✅ 更新状态
                    await transaction.finish()
                case .unverified(_, let error):
                    print("交易未经核实: \(error.localizedDescription)")
                }
            case .pending:
                print("购买挂起。。。")
            case .userCancelled:
                print("用户取消了购买.")
            @unknown default:
                print("未知购买结果。。。")
            }
        } catch {
            print("用户购买失败: \(error.localizedDescription)")
        }
    }
}
