//
//  PackageLanguage.swift
//  MySwiftAppTools
//
//  包内 UI 文案的语言切换。
//
//  ## 为什么需要这个文件
//
//  `Bundle.localizedString` 用的是 bundle 的「首选本地化」，而它由 Foundation 在
//  **进程启动时**按 `AppleLanguages` 解析并缓存。App 内切换语言（改 UserDefaults）
//  不会让它重新解析 —— 包内文案会一直停在启动时的语言上。
//
//  所以这里补两条管线：
//
//  1. 查表层 `PackageLocalization`：显式定位目标语言的 `.lproj` 再查表，绕开启动缓存；
//  2. 刷新层 `PackageLanguageManager` + `.packageLanguageRefresh()`：
//     语言变化时给出新的 `refreshToken`，由 SwiftUI 用 `.id(...)` 重建视图。
//
//  机制与 `SwiftHelpCenter` 的 `SHCLocalization` / `SHCAppLanguageManager` 对齐，
//  但**不依赖它** —— 本包是基础工具包，不该为改个语言背上一整坨 HelpCenter 依赖。
//

import Foundation
import SwiftUI

// MARK: - 语言

/// 包内 UI 文案使用的语言。
public enum PackageLanguage: Sendable, Equatable {

    /// 跟随系统语言（默认）。与包在 0.1.69 及以前的行为完全一致。
    case system

    /// 简体中文。
    case zhHans

    /// 英文。
    case english

    /// 任意 `.lproj` 资源名，用于对接外部语言系统。
    ///
    /// 例如直接传 `SwiftHelpCenter` 的 `SHCAppLanguagePreference.resourceName`
    /// （返回 `"zh-hans"` / `"en"`）。资源名匹配**大小写不敏感**。
    case custom(String)

    /// 对应的 `.lproj` 资源名；`nil` 表示交给 `Bundle.module` 默认解析。
    var resourceName: String? {
        switch self {
        case .system:           return nil
        case .zhHans:           return "zh-Hans"
        case .english:          return "en"
        case .custom(let name): return name
        }
    }
}

// MARK: - 查表层

/// 包内文案查表。
///
/// 对外只暴露 `resourceName` 与 `PackageLanguageManager`；查表入口仍是 `packageL`。
public enum PackageLocalization {

    /// 当前生效的 `.lproj` 资源名；`nil` = 走 `Bundle.module` 的默认解析（跟随系统）。
    ///
    /// 只在主线程写（由 `PackageLanguageManager` 负责），但查表路径要能从任意线程读，
    /// 因此用 `nonisolated(unsafe)`。
    nonisolated(unsafe) static var resourceName: String?

    private static let cacheLock = NSLock()
    nonisolated(unsafe) private static var bundleCache: [String: Bundle] = [:]

    /// 全局显式设置的语言（`nil` = 未设置）。
    ///
    /// 视图层需要「子树上的语言优先、全局其次」时用它做中间层。
    static var explicitResourceName: String? { resourceName }

    static func localizedFormat(
        _ key: String,
        resourceName override: String? = nil,
        arguments: [CVarArg]
    ) -> String {
        let format = localizedString(key, resourceName: override)
        return String(format: format, locale: .autoupdatingCurrent, arguments: arguments)
    }

    /// 查表。`resourceName` 传具体值时以它为准；传 `nil` 则回退到全局设置。
    static func localizedString(_ key: String, resourceName override: String? = nil) -> String {
        // 未指定语言（子树没传、全局也没设）：完全走原路径，行为与 0.1.69 及以前一致。
        guard let name = override ?? resourceName else {
            return Bundle.module.localizedString(forKey: key, value: nil, table: nil)
        }

        let resolved = resolvedLocalizationName(name)

        // 1. 定向 lproj Bundle —— 这是绕开启动期语言缓存的关键一步。
        if let bundle = lprojBundle(named: resolved) {
            return bundle.localizedString(forKey: key, value: nil, table: nil)
        }

        // 2. 兜底：直接读 .strings 文件（应对 SPM / Preview 下 lproj 不可达）。
        if let path = Bundle.module.path(
            forResource: "Localizable",
            ofType: "strings",
            inDirectory: "\(resolved).lproj"
        ),
           let table = NSDictionary(contentsOfFile: path) as? [String: String],
           let value = table[key] {
            return value
        }

        // 3. 最终回退：标准查表。
        return Bundle.module.localizedString(forKey: key, value: nil, table: nil)
    }

    /// 由 SwiftUI 环境里的 `Locale` 推导出应使用的 `.lproj` 资源名。
    ///
    /// **这是「不用调用方写桥接代码」的关键一条**：调用方（例如
    /// `SwiftHelpCenter` 的 `.SHCAppLanguage(...)`）通常已经往环境里注入了 `Locale`，
    /// 并在语言切换时重建子树。包内视图只要在 body 里读环境 `Locale`，
    /// 就能跟着一起变 —— 无需调用方再调任何 `setLanguage`。
    ///
    /// 只在 bundle 真正拥有的本地化目录里匹配；匹配不到返回 `nil`，
    /// 由调用方回退到标准查表（跟随系统）。
    static func resourceName(for locale: Locale) -> String? {
        let available = Bundle.module.localizations
        guard !available.isEmpty else { return nil }

        for candidate in localeCandidates(locale) {
            if let matched = available.first(where: {
                $0.compare(candidate, options: .caseInsensitive) == .orderedSame
            }) {
                return matched
            }
        }

        // 语言码前缀兜底：「zh-Hans_CN」命中 `zh-Hans.lproj` 这类带脚本的目录名。
        guard let language = primaryLanguageCode(of: locale) else { return nil }
        return available.first { $0.lowercased().hasPrefix(language.lowercased()) }
    }

    /// 依次尝试的候选目录名，从最具体到最宽松。
    ///
    /// `zh-Hans_CN` → `["zh-Hans_CN", "zh-Hans-CN", "zh-Hans", "zh"]`
    /// `en_US` → `["en_US", "en-US", "en"]`
    private static func localeCandidates(_ locale: Locale) -> [String] {
        let identifier = locale.identifier
        guard !identifier.isEmpty else { return [] }

        let hyphenated = identifier.replacingOccurrences(of: "_", with: "-")
        let parts = hyphenated.split(separator: "-").map(String.init)

        var result = [identifier]
        if hyphenated != identifier { result.append(hyphenated) }
        if parts.count >= 2 { result.append("\(parts[0])-\(parts[1])") }
        if let language = parts.first { result.append(language) }
        return result
    }

    /// `zh-Hans_CN` → `zh`。
    private static func primaryLanguageCode(of locale: Locale) -> String? {
        let identifier = locale.identifier
        guard !identifier.isEmpty else { return nil }
        return identifier
            .replacingOccurrences(of: "_", with: "-")
            .split(separator: "-")
            .first
            .map(String.init)
    }

    /// 在 bundle 实际拥有的本地化目录里做大小写不敏感匹配。
    ///
    /// 外部语言系统给的可能是小写 `"zh-hans"`，而本包目录名是 `zh-Hans.lproj`。
    /// macOS 默认文件系统大小写不敏感、通常能撞上，但不赌 —— 先按真实目录名对齐。
    private static func resolvedLocalizationName(_ name: String) -> String {
        let available = Bundle.module.localizations
        if available.contains(name) { return name }
        if let matched = available.first(where: {
            $0.compare(name, options: .caseInsensitive) == .orderedSame
        }) {
            return matched
        }
        return name
    }

    private static func lprojBundle(named name: String) -> Bundle? {
        cacheLock.lock()
        let cached = bundleCache[name]
        cacheLock.unlock()
        if let cached { return cached }

        guard let path = Bundle.module.path(forResource: name, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return nil
        }

        cacheLock.lock()
        bundleCache[name] = bundle
        cacheLock.unlock()
        return bundle
    }

    /// 清掉 lproj Bundle 缓存。语言切换时调用。
    static func invalidateCache() {
        cacheLock.lock()
        bundleCache.removeAll()
        cacheLock.unlock()
    }
}

// MARK: - 状态层

/// 包内语言状态，供 SwiftUI 观察。
///
/// ```swift
/// PackageLanguageManager.shared.setLanguage(.english)
/// ```
@MainActor
@Observable
public final class PackageLanguageManager {

    public static let shared = PackageLanguageManager()

    /// 当前语言。
    public private(set) var language: PackageLanguage = .system

    /// 语言变化时更新。`packageLanguageRefresh()` 与包内视图拿它作 `.id(...)`。
    public private(set) var refreshToken = UUID()

    public init() {}

    /// 切换包内语言。传入与当前相同的值不会触发重建。
    public func setLanguage(_ language: PackageLanguage) {
        guard language != self.language else { return }
        self.language = language
        PackageLocalization.resourceName = language.resourceName
        PackageLocalization.invalidateCache()
        refreshToken = UUID()
    }

    /// 直接指定 `.lproj` 资源名（`nil` = 跟随系统）。
    ///
    /// 便于对接外部语言系统 —— 把它的资源名原样传进来即可。
    public func setResourceName(_ name: String?) {
        setLanguage(name.map(PackageLanguage.custom) ?? .system)
    }

    /// 回到跟随系统语言。
    public func followSystem() {
        setLanguage(.system)
    }

    /// 语言没变也强制刷新一次（外部替换了资源文件之类的场景）。
    public func refresh() {
        refreshToken = UUID()
    }
}

// MARK: - 刷新层

public extension View {

    /// 让这棵子树跟随包内语言切换重建（命令式）。
    ///
    /// ```swift
    /// PackageLanguageManager.shared.setLanguage(.english)
    /// ```
    func packageLanguageRefresh(_ manager: PackageLanguageManager = .shared) -> some View {
        id(manager.refreshToken)
    }

    /// 让这棵子树跟随一个外部语言值**自动**刷新（推荐）。
    ///
    /// 值变化时自动同步进包内并重建整棵子树。套在每个 Window / Scene 的根视图上即可：
    ///
    /// ```swift
    /// RootView()
    ///     .packageLanguageRefresh(resourceName: languageManager.selection.resourceName)
    /// ```
    ///
    /// 传 `nil` 表示跟随系统语言。
    func packageLanguageRefresh(resourceName: String?) -> some View {
        modifier(PackageLanguageRefreshModifier(resourceName: resourceName))
    }
}

// MARK: - 环境注入

/// 子树上生效的包内语言（`.lproj` 资源名，`nil` = 未指定）。
private struct PackageLanguageResourceNameKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

public extension EnvironmentValues {

    /// 当前子树上生效的包内语言资源名。
    ///
    /// 由 `.packageLanguageRefresh(resourceName:)` 注入。包内视图在 `body` 里读它 ——
    /// 值一变就重算，这条路径**不依赖视图重建时序**，比 `onChange` 回调更可靠。
    var packageLanguageResourceName: String? {
        get { self[PackageLanguageResourceNameKey.self] }
        set { self[PackageLanguageResourceNameKey.self] = newValue }
    }
}

private struct PackageLanguageRefreshModifier: ViewModifier {

    let resourceName: String?

    func body(content: Content) -> some View {
        content
            // 1. 子树级注入：包内视图在 body 里读它，值一变就重算。
            //    这条最稳 —— 不依赖视图身份是否被重建。
            .environment(\.packageLanguageResourceName, resourceName)
            // 2. 全局同步：让不经过 SwiftUI 环境的调用方（AppKit 弹窗、独立窗口等）
            //    也能拿到新语言。`initial: true` 保证冷启动即同步，而非等用户再切一次。
            .onChange(of: resourceName, initial: true) { _, newValue in
                PackageLanguageManager.shared.setResourceName(newValue)
            }
            // 3. 强制重建：包内还有若干界面直接用 `packageL(...)` 而没读环境键，
            //    换掉 identity 是让它们也刷新的唯一手段。语义与
            //    `SwiftHelpCenter` 的 `.SHCAppLanguage(...)` 一致。
            .id(resourceName)
    }
}
