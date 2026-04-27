//
//  Localization.swift
//  RightClickMate
//
//  Created by yangxuehui on 2026/2/12.
//
import Foundation
//在外部调用使用
public func L(_ key: String, _ args: CVarArg...) -> String {
    String(format: NSLocalizedString(key, comment: ""), arguments: args)
}

//包里面使用
public func packageL(_ key: String, _ args: CVarArg...) -> String {
    let format = Bundle.module.localizedString(forKey: key, value: key, table: nil)
    return String(format: format, locale: Locale.current, arguments: args)
}
//包外使用
public extension String {

    /// AppKit / Finder Extension 使用
    var toNSLocalizedString: String {
        NSLocalizedString(self, comment: "")
    }

    /// 可选：显式指定 bundle（Finder Extension 用）
    func localized(in bundle: Bundle) -> String {
        NSLocalizedString(self, bundle: bundle, comment: "")
    }
}
//包内使用
public extension String {
    var toPackageNSLocalizedString: String {
        Bundle.module.localizedString(forKey: self, value: self, table: nil)
    }

    func PackageLocalized(in bundle: Bundle) -> String {
        bundle.localizedString(forKey: self, value: self, table: nil)
    }
}

public enum MySwiftAppToolsL10n {
    public static let authReadTitle = "PermissionManager.authReadTitle"
    public static let authReadMsg = "PermissionManager.authReadMsg"
    public static let authWriteTitle = "PermissionManager.authWriteTitle"
    public static let authWriteMsg = "PermissionManager.authWriteMsg"
    public static let copiedToPasteboard = "Toast.copiedToPasteboard"
    public static let confirmOK = "Toast.confirmOK"
}
