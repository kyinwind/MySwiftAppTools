//
//  ProGatekeeper.swift
//  RightClickMate
//
//  Created by yangxuehui on 2026/2/10.
//
import SwiftUI

enum ProFeature {
    //free用户只能新建固定的文件类型，pro用户可以自定义文件类型
    case createProOfficeFile
    //free用户修改文件名不超过20张，pro用户没有限制
    case batchRename
    case zip
    //free用户只能修改单张图片，pro用户可以同时修改多张图片
    case resizeImage
    //free用户只能复制5层，pro用户可以复制20层
    case copyTree
    
    // 拆开隐私橡皮擦
    //case blurImage
    case privacyOCR
    //pro用户可以使用Ai修复没有限制，免费用户则每天都有使用次数的限制
    case privacyAIRepair
    //pro用户可以批量处理，free用户只能一张一张处理
    case privacyBatch
    //pro用户可以导出导入
    case exportAndImport
    //可以增加快速应用，免费用户只能显示历史记录，pro用户可以自己指定常用app
    case quickApp
}
/*
 DefaultsTools保存用过的次数，以及最新的日期。
 */
@MainActor
class ProGatekeeper {
    static var hasPurchasedPro: () -> Bool = { false }
    static var presentPurchase: () -> Void = {
        NSApp.activate(ignoringOtherApps: true)
        NSWorkspace.shared.open(
            URL(string: "rightclickmate://purchase")!
        )
    }

    static let freeLimits: [ProFeature: Int] = [
        .privacyOCR: 10,  //free用户每天 10 次
        .privacyAIRepair: 5,  //free 用户每天 5 次
        .privacyBatch: 0, // ❗free 完全禁止
    ]
    
    /// ⭐ 唯一对外入口（安全）
    @MainActor
    static func check(_ feature: ProFeature) async -> Bool {
        if allow(feature) {
            consume(feature) // ⭐ 成功才消耗
            return true
        } else {
            block(feature)
            return false
        }
    }
    
    private static func consume(_ feature: ProFeature) {
        guard !hasPurchasedPro() else { return }
        guard freeLimits[feature] != nil else { return }
        resetIfNeeded() // ⭐ 加这一行
        let key = keyForFeature(feature)
        let current = DefaultsTools.shared.int(key) ?? 0
        DefaultsTools.shared.set(current + 1, for: key)
    }
    /// 判断是否允许使用某个 Pro 功能
    static func allow(_ feature: ProFeature) -> Bool {
        
        // Pro 用户直接放行
        if hasPurchasedPro() {
            return true
        }
        else{
            //这三个有计数，允许 free 用户每天使用一定的次数
            if feature == .privacyAIRepair || feature == .privacyOCR || feature == .privacyBatch {
                // 非限制功能直接放行
                guard let limit = freeLimits[feature] else {
                    return false
                }
                
                resetIfNeeded()
                
                let current = currentCount(for: feature)
                
                return current < limit
            }
        }
        return false
    }
    //取出今天已经用了多少次
    private static func currentCount(for feature: ProFeature) -> Int {
        let key = keyForFeature(feature)
        return DefaultsTools.shared.int(key) ?? 0
    }
    //查询还剩多少次
    static func remaining(_ feature: ProFeature) -> Int? {
        guard let limit = freeLimits[feature] else { return nil }
        
        if hasPurchasedPro() {
            return nil
        }
        
        resetIfNeeded()
        
        let current = currentCount(for: feature)
        return max(0, limit - current)
    }
    /// 不允许时的统一处理
    @MainActor
    private static func block(_ feature: ProFeature) {
        presentPurchase()
    }
    
    private static func keyForFeature(_ feature: ProFeature) -> DefaultsTools.Key {
        switch feature {
        case .privacyOCR:
            return .ocrCount
        case .privacyAIRepair:
            return .aiRepairCount
        case .privacyBatch:
            return .privacyEraserBatch
        default:
            fatalError("No key for feature: \(feature)")
        }
    }
    //resetIfNeeded() 用来在“跨天时清零使用次数”
    private static func resetIfNeeded() {
        let today = Calendar.current.startOfDay(for: Date())
        let last = DefaultsTools.shared.value(for: .lastResetDate) as Date? ?? .distantPast
        
        if !Calendar.current.isDate(today, inSameDayAs: last) {
            
            for feature in freeLimits.keys {
                let key = keyForFeature(feature)
                DefaultsTools.shared.set(0, for: key)
            }
            
            DefaultsTools.shared.set(today, for: .lastResetDate)
        }
    }
    
     static func debugReset() {
        let today = Calendar.current.startOfDay(for: Date())
         DefaultsTools.shared.set(0, for: .ocrCount)
         DefaultsTools.shared.set(0, for: .aiRepairCount)
         DefaultsTools.shared.set(today, for: .lastResetDate)
    }
}

