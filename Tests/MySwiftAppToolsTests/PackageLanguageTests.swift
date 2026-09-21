import Foundation
import XCTest
@testable import MySwiftAppTools

/// 包内语言切换的查表与刷新行为。
///
/// 背景：`Bundle.localizedString` 的语言选择由 Foundation 在进程启动时解析并缓存，
/// App 内切语言不会让它重新解析 —— 这组用例守住「定向 lproj 查表」这条绕行路径，
/// 以及「默认行为必须与 0.1.69 及以前逐 key 一致」这条底线。
@MainActor
final class PackageLanguageTests: XCTestCase {

    override func setUp() async throws {
        // 语言是进程级全局状态，测完必须复位，否则会污染同进程里的其他用例。
        PackageLanguageManager.shared.followSystem()
    }

    override func tearDown() async throws {
        PackageLanguageManager.shared.followSystem()
    }

    /// 从 bundle 里实际存在的 lproj 收集全部 key。
    ///
    /// 用「读文件」而不是硬编码清单：以后加文案不会漏测，同时顺带验证
    /// `path(forResource:ofType:inDirectory:)` 这条定位方式在 SPM bundle 下确实可用。
    private static var allLocalizationKeys: [String] {
        var keys = Set<String>()
        for name in Bundle.module.localizations {
            guard let path = Bundle.module.path(
                forResource: "Localizable",
                ofType: "strings",
                inDirectory: "\(name).lproj"
            ),
                let table = NSDictionary(contentsOfFile: path) as? [String: String]
            else { continue }
            keys.formUnion(table.keys)
        }
        return keys.sorted()
    }

    // MARK: - 默认行为

    func testDefaultMatchesLegacyLookupForKeyByKey() {
        let keys = Self.allLocalizationKeys
        XCTAssertFalse(keys.isEmpty, "没能从 lproj 里读到任何 key，先确认资源打包方式")

        for key in keys {
            // 比的是「查表结果」，所以走未格式化的 internal 入口 ——
            // packageL 会顺带 String(format:) 一次，含 %d 的文案会被填成 0，两者不可比。
            XCTAssertEqual(
                PackageLocalization.localizedString(key),
                Bundle.module.localizedString(forKey: key, value: nil, table: nil),
                "未指定语言时 packageL(\(key)) 必须走原路径"
            )
        }
    }

    // MARK: - 定向查表

    func testSwitchingLanguageChangesText() {
        PackageLanguageManager.shared.setLanguage(.english)
        XCTAssertEqual(packageL(MySwiftAppToolsL10n.toastHistoryTitle), "Message History")

        PackageLanguageManager.shared.setLanguage(.zhHans)
        XCTAssertEqual(packageL(MySwiftAppToolsL10n.toastHistoryTitle), "消息历史")
    }

    func testFormattedKeysUseTargetLanguage() {
        PackageLanguageManager.shared.setLanguage(.english)
        XCTAssertEqual(packageL(MySwiftAppToolsL10n.toastHistoryCount, 3), "3 messages")
        XCTAssertEqual(packageL(MySwiftAppToolsL10n.toastHistoryMinutesAgo, 5), "5 min ago")

        PackageLanguageManager.shared.setLanguage(.zhHans)
        XCTAssertEqual(packageL(MySwiftAppToolsL10n.toastHistoryCount, 3), "共 3 条")
        XCTAssertEqual(packageL(MySwiftAppToolsL10n.toastHistoryMinutesAgo, 5), "5 分钟前")
    }

    /// 外部语言系统（如 SwiftHelpCenter）给的资源名是小写 `zh-hans`，
    /// 而本包目录名是 `zh-Hans.lproj` —— 必须撞得上。
    func testCustomResourceNameMatchesCaseInsensitively() {
        PackageLanguageManager.shared.setResourceName("zh-hans")
        XCTAssertEqual(packageL(MySwiftAppToolsL10n.toastHistoryTitle), "消息历史")

        PackageLanguageManager.shared.setResourceName("ZH-HANS")
        XCTAssertEqual(packageL(MySwiftAppToolsL10n.toastHistoryTitle), "消息历史")
    }

    func testUnknownResourceNameFallsBackInsteadOfCrashing() {
        PackageLanguageManager.shared.setResourceName("ja")
        // 包内没有日文资源：不能崩，也不能返回空串 —— 应回退到 bundle 默认解析。
        XCTAssertFalse(packageL(MySwiftAppToolsL10n.toastHistoryTitle).isEmpty)
    }

    func testNilResourceNameFollowsSystem() {
        PackageLanguageManager.shared.setLanguage(.english)
        PackageLanguageManager.shared.setResourceName(nil)

        XCTAssertEqual(PackageLanguageManager.shared.language, .system)
        XCTAssertEqual(
            packageL(MySwiftAppToolsL10n.toastHistoryTitle),
            Bundle.module.localizedString(forKey: "Toast.History.title", value: nil, table: nil)
        )
    }

    // MARK: - 状态与刷新

    func testRefreshTokenChangesOnlyWhenLanguageActuallyChanges() {
        PackageLanguageManager.shared.followSystem()
        let initial = PackageLanguageManager.shared.refreshToken

        PackageLanguageManager.shared.setLanguage(.system)
        XCTAssertEqual(
            PackageLanguageManager.shared.refreshToken,
            initial,
            "重复设置同一个值不该触发视图重建"
        )

        PackageLanguageManager.shared.setLanguage(.english)
        XCTAssertNotEqual(
            PackageLanguageManager.shared.refreshToken,
            initial,
            "语言真的变了就必须换 token，否则界面不会重绘"
        )

        let afterSwitch = PackageLanguageManager.shared.refreshToken
        PackageLanguageManager.shared.refresh()
        XCTAssertNotEqual(
            PackageLanguageManager.shared.refreshToken,
            afterSwitch,
            "refresh() 应能在语言不变时强制换 token"
        )
    }

    // MARK: - 语言枚举

    func testLanguageResourceNames() {
        XCTAssertNil(PackageLanguage.system.resourceName, ".system 应交给 bundle 默认解析")
        XCTAssertEqual(PackageLanguage.zhHans.resourceName, "zh-Hans")
        XCTAssertEqual(PackageLanguage.english.resourceName, "en")
        XCTAssertEqual(PackageLanguage.custom("ja").resourceName, "ja")
    }
}
