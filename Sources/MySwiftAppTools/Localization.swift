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
    public static let downloaderNoValidUrls = "MultiSourceDownloader.noValidUrls"
    public static let downloaderAllSourcesFailed = "MultiSourceDownloader.allSourcesFailed"
    public static let downloaderVerificationFailed = "MultiSourceDownloader.verificationFailed"
    public static let downloaderInvalidResponse = "MultiSourceDownloader.invalidResponse"
    public static let downloaderFileAlreadyExists = "MultiSourceDownloader.fileAlreadyExists"
    public static let themeCustomTextViewPlaceholder = "ThemeManager.CustomTextView.placeholder"
    public static let actionBarAdd = "ThemeManager.ActionBar.add"
    public static let actionBarEdit = "ThemeManager.ActionBar.edit"
    public static let actionBarDelete = "ThemeManager.ActionBar.delete"
    public static let actionBarSave = "ThemeManager.ActionBar.save"
    public static let actionBarExit = "ThemeManager.ActionBar.exit"
    public static let actionBarPreviewDragWidth = "ThemeManager.ActionBar.preview.dragWidth"
    public static let actionBarPreviewExport = "ThemeManager.ActionBar.preview.export"
    public static let helpCenterHelp = "RCMHelpCenter.help"
    public static let helpCenterVersionHistory = "RCMHelpCenter.versionHistory"
    public static let helpCenterVersionHistorySubtitle = "RCMHelpCenter.versionHistorySubtitle"
    public static let helpCenterViewContent = "RCMHelpCenter.viewContent"
    public static let helpCenterBilibili = "RCMHelpCenter.bilibili"
    public static let helpCenterYoutube = "RCMHelpCenter.youtube"
    public static let helpCenterNew = "RCMHelpCenter.new"
    public static let helpCenterUnread = "RCMHelpCenter.unread"
    public static let helpCenterNoVersionHistory = "RCMHelpCenter.noVersionHistory"
    public static let helpCenterNoVersionHistoryMessage = "RCMHelpCenter.noVersionHistoryMessage"
    public static let helpCenterOpenSupport = "RCMHelpCenter.openSupport"
    public static let helpCenterMarkAllRead = "RCMHelpCenter.markAllRead"
}
