import SwiftUI
import XCTest
import MySwiftAppTools

@MainActor
final class PublicAPITests: XCTestCase {
    func testDesignSystemPublicEntrypointsCompile() throws {
        try RCMTheme.shared.applyDefaultThemeFromPackage()
        RCMTheme.shared.applyPreset(.orange)
        RCMTheme.shared.configure { tokens in
            tokens.colors.primary = Color(hex: "#3185FF")
            tokens.spacing.md = 16
        }

        let partialJSON = """
        {
          "colors": { "primary": "#FF6B00" },
          "shadow": { "opacity": 0.08 }
        }
        """.data(using: .utf8)!
        try RCMTheme.shared.configure(jsonData: partialJSON)

        _ = RCMButton("保存", role: .primary, systemImage: "checkmark") {}
        _ = RCMBadge("Pro", style: .accent)
        let badgeText = "String Variable"
        _ = RCMBadge(badgeText, style: .success)
        _ = RCMBadge(verbatim: "1.0.0", style: .neutral)
        _ = RCMToggle(isOn: .constant(true), localizedLabel: "自动更新")
        _ = RCMCard { Text("Card") }
        _ = RCMPageSection("设置") { Text("Content") }
        _ = RCMHeroPanel { Text("Hero") }
        _ = RCMSettingRow("标题", subtitle: "说明") { Text("Value") }
    }

    func testToolPublicEntrypointsCompile() async {
        DefaultsTools.configure(appGroupID: "MySwiftAppToolsTests")
        DefaultsTools.shared.set("value", for: "public.api.test")
        XCTAssertEqual(DefaultsTools.shared.string("public.api.test"), "value")
        DefaultsTools.shared.remove("public.api.test")

        KeychainTools.configure(defaultService: "MySwiftAppToolsTests")
        Log.configure(subsystem: "MySwiftAppToolsTests", isEnabled: false)

        ToastManager.shared.configure(maxVisibleToasts: 3)
        ToastManager.shared.show("测试", duration: 0.01)
        ToastManager.shared.hideAll()

        _ = StoreManager(productIDs: ["test.product"], proProductID: "test.product", autoStart: false)

        ProGatekeeper.shared.configure(
            freeLimits: ["feature": 1],
            keyPrefix: "MySwiftAppToolsTests.ProGatekeeper",
            hasPurchasedPro: { false },
            presentPurchase: {}
        )
        _ = ProGatekeeper.shared.allow("feature")

        _ = ComponentState(isBusy: false, isFinished: true)
        _ = ComponentsFlowManager<String, String>()
        _ = PermissionManager.shared
    }
}
