import CoreGraphics
import XCTest
@testable import MySwiftAppTools

final class SegmentedPageNavigatorTests: XCTestCase {
    func testMetricsDistributeRowsAcrossAllAvailableHeight() {
        let metrics = SegmentedPageNavigatorMetrics(
            availableHeight: 500,
            itemCount: 71
        )

        XCTAssertEqual(metrics.rowHeight, 500.0 / 71.0, accuracy: 0.0001)
        XCTAssertEqual(metrics.segmentHeight, 3)
        XCTAssertEqual(metrics.contentTop, 0)
        XCTAssertEqual(metrics.centerY(for: 0), 250.0 / 71.0, accuracy: 0.0001)
        XCTAssertEqual(metrics.centerY(for: 70), 500.0 - 250.0 / 71.0, accuracy: 0.0001)
    }

    func testMetricsSpreadSmallPageCountWithoutChangingSegmentThickness() {
        let metrics = SegmentedPageNavigatorMetrics(
            availableHeight: 120,
            itemCount: 5
        )

        XCTAssertEqual(metrics.rowHeight, 24)
        XCTAssertEqual(metrics.segmentHeight, 3)
        XCTAssertEqual(metrics.centerY(for: 0), 12)
        XCTAssertEqual(metrics.centerY(for: 4), 108)
    }

    func testMetricsCompressLargePageCountsIntoAvailableHeight() {
        let metrics = SegmentedPageNavigatorMetrics(
            availableHeight: 400,
            itemCount: 200
        )

        XCTAssertEqual(metrics.contentTop, 0)
        XCTAssertEqual(metrics.rowHeight, 2)
        XCTAssertEqual(metrics.segmentHeight, 1.2, accuracy: 0.0001)
        XCTAssertEqual(metrics.centerY(for: 199), 399)
    }

    func testTooltipPositionStaysInsideAvailableHeight() {
        let metrics = SegmentedPageNavigatorMetrics(
            availableHeight: 100,
            itemCount: 20
        )

        XCTAssertEqual(metrics.tooltipCenterY(for: 0, tooltipHeight: 24), 12)
        XCTAssertEqual(metrics.tooltipCenterY(for: 19, tooltipHeight: 24), 88)
    }

    func testEmptyMetricsRemainFinite() {
        let metrics = SegmentedPageNavigatorMetrics(
            availableHeight: 0,
            itemCount: 0
        )

        XCTAssertEqual(metrics.contentTop, 0)
        XCTAssertEqual(metrics.rowHeight, 0)
        XCTAssertEqual(metrics.segmentHeight, 0)
    }
}
