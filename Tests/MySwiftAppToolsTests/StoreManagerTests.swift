import StoreKit
import XCTest
@testable import MySwiftAppTools

@MainActor
final class StoreManagerTests: XCTestCase {
    private let lifetimeID = "test.pro.lifetime"
    private let yearlyID = "test.pro.yearly"

    func testEitherConfiguredProductGrantsSharedProEntitlement() {
        let manager = makeManager()

        manager.applyActiveEntitlements([
            yearlyID: entitlement(yearlyID, expirationDate: Date().addingTimeInterval(86_400))
        ])

        XCTAssertTrue(manager.hasPurchasedPro)
        XCTAssertTrue(manager.isPurchased(yearlyID))
        XCTAssertFalse(manager.isPurchased(lifetimeID))
    }

    func testLifetimePurchaseGrantsProWithoutExpiration() {
        let manager = makeManager()

        manager.applyActiveEntitlements([
            lifetimeID: entitlement(lifetimeID)
        ])

        XCTAssertTrue(manager.hasPurchasedPro)
        XCTAssertNil(manager.entitlement(for: lifetimeID)?.expirationDate)
    }

    func testRebuildClearsStaleSubscriptionEntitlement() {
        let manager = makeManager()
        manager.applyActiveEntitlements([
            yearlyID: entitlement(yearlyID, expirationDate: Date().addingTimeInterval(86_400))
        ])
        XCTAssertTrue(manager.hasPurchasedPro)

        manager.applyActiveEntitlements([:])

        XCTAssertFalse(manager.hasPurchasedPro)
        XCTAssertFalse(manager.isPurchased(yearlyID))
        XCTAssertTrue(manager.hasLoadedEntitlements)
    }

    func testUnrelatedEntitlementDoesNotGrantPro() {
        let manager = makeManager()

        manager.applyActiveEntitlements([
            "test.tip": entitlement("test.tip")
        ])

        XCTAssertFalse(manager.hasPurchasedPro)
    }

    func testLegacySingleProductConfigurationStillWorks() {
        let manager = StoreManager(
            productIDs: [lifetimeID],
            proProductID: lifetimeID,
            autoStart: false
        )

        manager.applyActiveEntitlements([
            lifetimeID: entitlement(lifetimeID)
        ])

        XCTAssertEqual(manager.proEntitlementProductIDs, [lifetimeID])
        XCTAssertTrue(manager.hasPurchasedPro)
    }

    func testProductOrderFollowsConfiguredProductIDs() {
        let manager = makeManager()

        XCTAssertLessThan(manager.productOrder(yearlyID), manager.productOrder(lifetimeID))
        XCTAssertEqual(manager.productOrder("test.unknown"), .max)
    }

    func testProGatekeeperPreparesEntitlementBeforeCheckingAccess() async {
        var prepared = false
        ProGatekeeper.shared.configure(
            freeLimits: [:],
            keyPrefix: "StoreManagerTests.\(UUID().uuidString)",
            hasPurchasedPro: { prepared },
            presentPurchase: {
                XCTFail("Purchase UI should not be shown after entitlement preparation")
            },
            prepareAccess: {
                prepared = true
            }
        )

        let allowed = await ProGatekeeper.shared.check("test.pro.only")

        XCTAssertTrue(prepared)
        XCTAssertTrue(allowed)
    }

    private func makeManager() -> StoreManager {
        StoreManager(
            productIDs: [yearlyID, lifetimeID],
            proEntitlementProductIDs: [yearlyID, lifetimeID],
            autoStart: false
        )
    }

    private func entitlement(
        _ productID: String,
        expirationDate: Date? = nil
    ) -> StoreEntitlementRecord {
        StoreEntitlementRecord(
            productID: productID,
            purchaseDate: Date(),
            expirationDate: expirationDate,
            ownershipType: .purchased
        )
    }
}
