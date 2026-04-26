//
//  Localization.swift
//  RightClickMate
//
//  Created by yangxuehui on 2026/2/12.
//
import Foundation

public func L(_ key: String, _ args: CVarArg...) -> String {
    let format = Bundle.module.localizedString(forKey: key, value: key, table: nil)
    return String(format: format, locale: Locale.current, arguments: args)
}

public extension String {
    var toNSLocalizedString: String {
        Bundle.module.localizedString(forKey: self, value: self, table: nil)
    }

    func localized(in bundle: Bundle) -> String {
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
