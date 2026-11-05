//
//  SegmentedPageNavigator.swift
//  MySwiftAppTools
//
//  A compact minimap-style navigator for long, vertically scrolling content.
//

import SwiftUI

/// A page represented by one segment in ``SegmentedPageNavigator``.
public struct SegmentedPageNavigatorItem<ID: Hashable>: Identifiable {
    public let id: ID
    public let pageNumber: Int

    public init(id: ID, pageNumber: Int) {
        self.id = id
        self.pageNumber = pageNumber
    }
}

struct SegmentedPageNavigatorMetrics: Equatable {
    static let preferredSegmentHeight: CGFloat = 3
    static let preferredSpacing: CGFloat = 2

    let contentTop: CGFloat
    let rowHeight: CGFloat
    let segmentHeight: CGFloat
    let availableHeight: CGFloat
    private let firstCenterOffset: CGFloat

    init(availableHeight: CGFloat, itemCount: Int) {
        self.availableHeight = max(0, availableHeight)

        guard itemCount > 0 else {
            contentTop = 0
            rowHeight = 0
            segmentHeight = 0
            firstCenterOffset = 0
            return
        }

        let count = CGFloat(itemCount)
        let preferredContentHeight = count * Self.preferredSegmentHeight
            + max(0, count - 1) * Self.preferredSpacing
        if self.availableHeight >= preferredContentHeight {
            contentTop = (self.availableHeight - preferredContentHeight) / 2
            rowHeight = Self.preferredSegmentHeight + Self.preferredSpacing
            segmentHeight = Self.preferredSegmentHeight
            firstCenterOffset = Self.preferredSegmentHeight / 2
        } else {
            contentTop = 0
            rowHeight = self.availableHeight / count
            segmentHeight = min(
                Self.preferredSegmentHeight,
                max(1, rowHeight * 0.6)
            )
            firstCenterOffset = rowHeight / 2
        }
    }

    func centerY(for index: Int) -> CGFloat {
        contentTop + firstCenterOffset + rowHeight * CGFloat(index)
    }

    func tooltipCenterY(for index: Int, tooltipHeight: CGFloat) -> CGFloat {
        let halfHeight = tooltipHeight / 2
        return min(
            max(centerY(for: index), halfHeight),
            max(halfHeight, availableHeight - halfHeight)
        )
    }
}

/// A minimap-style vertical navigator whose short segments represent pages.
///
/// The current page is highlighted. Hovering a segment shows the label supplied
/// by `pageLabel`, and clicking the segment invokes `onSelect` with that page's ID.
public struct SegmentedPageNavigator<ID: Hashable>: View {
    public let items: [SegmentedPageNavigatorItem<ID>]
    public let currentID: ID?
    public let pageLabel: (Int) -> String
    public let onSelect: (ID) -> Void

    @State private var hoveredID: ID?

    private let activeColor: Color
    private let inactiveColor: Color
    private let horizontalPadding: CGFloat
    private let segmentHalfHitWidth: CGFloat = 11
    private let tooltipWidth: CGFloat = 78
    private let tooltipHeight: CGFloat = 24

    private var segmentX: CGFloat {
        horizontalPadding + segmentHalfHitWidth
    }

    private var segmentHitWidth: CGFloat {
        (horizontalPadding + segmentHalfHitWidth) * 2
    }

    public init(
        items: [SegmentedPageNavigatorItem<ID>],
        currentID: ID?,
        activeColor: Color = .accentColor,
        inactiveColor: Color = .secondary.opacity(0.42),
        horizontalPadding: CGFloat = 8,
        pageLabel: @escaping (Int) -> String,
        onSelect: @escaping (ID) -> Void
    ) {
        self.items = items
        self.currentID = currentID
        self.activeColor = activeColor
        self.inactiveColor = inactiveColor
        self.horizontalPadding = max(0, horizontalPadding)
        self.pageLabel = pageLabel
        self.onSelect = onSelect
    }

    public var body: some View {
        GeometryReader { geometry in
            let metrics = SegmentedPageNavigatorMetrics(
                availableHeight: geometry.size.height,
                itemCount: items.count
            )

            ZStack(alignment: .topLeading) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    segmentButton(item, metrics: metrics, index: index)
                }

                if let hoveredIndex,
                   items.indices.contains(hoveredIndex) {
                    Text(pageLabel(items[hoveredIndex].pageNumber))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 8)
                        .frame(minWidth: tooltipWidth, minHeight: tooltipHeight)
                        .background(.regularMaterial, in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(.primary.opacity(0.12), lineWidth: 1)
                        }
                        .shadow(color: .black.opacity(0.16), radius: 5, y: 2)
                        .position(
                            x: segmentX + 12 + tooltipWidth / 2,
                            y: metrics.tooltipCenterY(
                                for: hoveredIndex,
                                tooltipHeight: tooltipHeight
                            )
                        )
                        .allowsHitTesting(false)
                        .zIndex(1)
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.12), value: hoveredID)
        }
        // Only the rail participates in the parent's layout. The tooltip may
        // overflow to the trailing side, so hosts can reserve a symmetric rail
        // without also reserving the transient tooltip width.
        .frame(width: segmentHitWidth)
        .accessibilityElement(children: .contain)
    }

    private var hoveredIndex: Int? {
        guard let hoveredID else { return nil }
        return items.firstIndex(where: { $0.id == hoveredID })
    }

    private func segmentButton(
        _ item: SegmentedPageNavigatorItem<ID>,
        metrics: SegmentedPageNavigatorMetrics,
        index: Int
    ) -> some View {
        let isCurrent = item.id == currentID
        let isHovered = item.id == hoveredID
        let label = pageLabel(item.pageNumber)

        return Button {
            onSelect(item.id)
        } label: {
            Capsule()
                .fill(segmentColor(isCurrent: isCurrent, isHovered: isHovered))
                .frame(
                    width: isCurrent || isHovered ? 12 : 7,
                    height: metrics.segmentHeight
                )
        }
        .buttonStyle(.plain)
        // Constrain the Button itself before moving it. Applying `position` to an
        // unconstrained Button can leave every page with the full GeometryReader
        // hit region, so the last page wins all hover events.
        .frame(width: segmentHitWidth, height: max(1, metrics.rowHeight))
        .contentShape(Rectangle())
        .offset(
            x: 0,
            y: metrics.centerY(for: index) - max(1, metrics.rowHeight) / 2
        )
        .onHover { isInside in
            if isInside {
                hoveredID = item.id
            } else if hoveredID == item.id {
                hoveredID = nil
            }
        }
        .accessibilityLabel(label)
        .accessibilityAddTraits(isCurrent ? [.isSelected] : [])
    }

    private func segmentColor(isCurrent: Bool, isHovered: Bool) -> Color {
        if isCurrent {
            return activeColor
        }
        if isHovered {
            return Color.primary.opacity(0.72)
        }
        return inactiveColor
    }
}

#if DEBUG
#Preview("Segmented page navigator") {
    SegmentedPageNavigator(
        items: (1...71).map {
            SegmentedPageNavigatorItem(id: $0, pageNumber: $0)
        },
        currentID: 50,
        pageLabel: { "Page \($0)" },
        onSelect: { _ in }
    )
    .frame(height: 520)
    .padding()
}
#endif
