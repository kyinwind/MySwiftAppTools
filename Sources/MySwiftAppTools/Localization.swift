//
//  Localization.swift
//  RightClickMate
//
//  Created by yangxuehui on 2026/2/12.
//
import Foundation

// MARK: - App-facing localization helpers

/// App 侧通用本地化函数。
///
/// 兼容已有调用方式，同时底层改为走 `RCMLocalization`，让用户手动指定语言后旧代码也能生效。
public func L(_ key: String, _ args: CVarArg...) -> String {
    RCMLocalization.localizedFormat(key, arguments: args)
}

/// MySwiftAppTools 包内部资源的本地化函数。
///
/// 与 `L` 的区别是默认从 `Bundle.module` 查表，用于公共包自带 UI 文案。
public func packageL(_ key: String, _ args: CVarArg...) -> String {
    RCMLocalization.localizedFormat(key, bundle: .module, arguments: args)
}

public extension String {

    /// AppKit / Finder Extension 使用的便捷入口。
    ///
    /// 返回 `String`，适合 NSAlert、NSMenu、NSButton 等不接受 `LocalizedStringKey` 的场景。
    var toNSLocalizedString: String {
        RCMLocalization.localizedString(self)
    }

    /// 显式指定 bundle 的查表入口。
    ///
    /// Finder Extension 或多 bundle 结构下，可以把目标 bundle 传进来。
    func localized(in bundle: Bundle) -> String {
        RCMLocalization.localizedString(self, bundle: bundle)
    }
}

public extension String {
    /// MySwiftAppTools 包内部资源的字符串查表入口。
    var toPackageNSLocalizedString: String {
        RCMLocalization.localizedString(self, bundle: .module)
    }

    /// 显式传入 bundle 的包内查表入口，保留原有 API 命名以兼容旧代码。
    func PackageLocalized(in bundle: Bundle) -> String {
        RCMLocalization.localizedString(self, bundle: bundle)
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
    public static let helpCenterTitle = "RCMHelpCenter.title"
    public static let helpCenterQuickLinks = "RCMHelpCenter.quickLinks"
    public static let helpCenterFeedback = "RCMHelpCenter.feedback"
    public static let helpCenterRate = "RCMHelpCenter.rate"
    public static let helpCenterFAQ = "RCMHelpCenter.faq"
    public static let helpCenterVersionHistory = "RCMHelpCenter.versionHistory"
    public static let helpCenterVersionHistorySubtitle = "RCMHelpCenter.versionHistorySubtitle"
    public static let helpCenterBilibili = "RCMHelpCenter.bilibili"
    public static let helpCenterYoutube = "RCMHelpCenter.youtube"
    public static let helpCenterNew = "RCMHelpCenter.new"
    public static let helpCenterUnread = "RCMHelpCenter.unread"
    public static let helpCenterNoVersionHistory = "RCMHelpCenter.noVersionHistory"
    public static let helpCenterNoVersionHistoryMessage = "RCMHelpCenter.noVersionHistoryMessage"
    public static let helpCenterOpenSupport = "RCMHelpCenter.openSupport"
    public static let helpCenterMarkAllRead = "RCMHelpCenter.markAllRead"
}
