//
//  Localization.swift
//  RightClickMate
//
//  Created by yangxuehui on 2026/2/12.
//
import Foundation

func L(_ key: String, _ args: CVarArg...) -> String {
    let format = Bundle.module.localizedString(forKey: key, value: key, table: nil)
    return String(format: format, locale: Locale.current, arguments: args)
}

extension String {
    var toNSLocalizedString: String {
        Bundle.module.localizedString(forKey: self, value: self, table: nil)
    }

    func localized(in bundle: Bundle) -> String {
        bundle.localizedString(forKey: self, value: self, table: nil)
    }
}

enum MySwiftAppToolsL10n {
    static let authReadTitle = "PermissionManager.authReadTitle"
    static let authReadMsg = "PermissionManager.authReadMsg"
    static let authWriteTitle = "PermissionManager.authWriteTitle"
    static let authWriteMsg = "PermissionManager.authWriteMsg"
    static let copiedToPasteboard = "Toast.copiedToPasteboard"
    static let confirmOK = "Toast.confirmOK"
}
