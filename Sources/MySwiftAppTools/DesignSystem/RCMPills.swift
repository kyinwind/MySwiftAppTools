import SwiftUI

// MARK: - RCMFlowLayout

/// 简单流式布局。子视图会按可用宽度自动换行。
public struct RCMFlowLayout: Layout {
    public var horizontalSpacing: CGFloat
    public var verticalSpacing: CGFloat

    public init(
        horizontalSpacing: CGFloat = RCMTheme.shared.spacing.sm,
        verticalSpacing: CGFloat = RCMTheme.shared.spacing.sm
    ) {
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
    }

    public func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) -> CGSize {
        let availableWidth = proposal.width ?? .infinity
        let rows = makeRows(subviews: subviews, availableWidth: availableWidth)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.reduce(CGFloat.zero) { partial, row in
            partial + row.height
        } + verticalSpacing * CGFloat(max(0, rows.count - 1))

        return CGSize(
            width: proposal.width ?? width,
            height: height
        )
    }

    public func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) {
        let rows = makeRows(subviews: subviews, availableWidth: bounds.width)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + horizontalSpacing
            }
            y += row.height + verticalSpacing
        }
    }

    private func makeRows(subviews: Subviews, availableWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let nextWidth = current.indices.isEmpty
                ? size.width
                : current.width + horizontalSpacing + size.width

            if nextWidth > availableWidth, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }

            current.indices.append(index)
            current.width = current.indices.count == 1
                ? size.width
                : current.width + horizontalSpacing + size.width
            current.height = max(current.height, size.height)
        }

        if !current.indices.isEmpty {
            rows.append(current)
        }

        return rows
    }

    private struct Row {
        var indices: [Subviews.Index] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }
}

// MARK: - RCMPillTone

public struct RCMPillTone: Sendable {
    public var background: Color
    public var foreground: Color
    public var border: Color

    public init(
        background: Color,
        foreground: Color,
        border: Color? = nil
    ) {
        self.background = background
        self.foreground = foreground
        self.border = border ?? foreground.opacity(0.16)
    }

    public static let defaultPalette: [RCMPillTone] = [
        RCMPillTone(background: Color(hexRGB: "#EAF2FF"), foreground: Color(hexRGB: "#246BCE")),
        RCMPillTone(background: Color(hexRGB: "#EAF8F0"), foreground: Color(hexRGB: "#218B4E")),
        RCMPillTone(background: Color(hexRGB: "#FFF4E6"), foreground: Color(hexRGB: "#B76100")),
        RCMPillTone(background: Color(hexRGB: "#F3EDFF"), foreground: Color(hexRGB: "#6F42C1")),
        RCMPillTone(background: Color(hexRGB: "#EAF7FA"), foreground: Color(hexRGB: "#087990")),
        RCMPillTone(background: Color(hexRGB: "#FDECEF"), foreground: Color(hexRGB: "#C7354D"))
    ]
}

// MARK: - RCMPill

public struct RCMPill: View {
    let title: String
    let tone: RCMPillTone
    let minWidth: CGFloat?
    let showsRemoveButton: Bool
    let action: (() -> Void)?
    let onRemove: (() -> Void)?
    @State private var isHovering = false

    public init(
        _ title: String,
        tone: RCMPillTone,
        minWidth: CGFloat? = nil,
        showsRemoveButton: Bool = false,
        action: (() -> Void)? = nil,
        onRemove: (() -> Void)? = nil
    ) {
        self.title = title
        self.tone = tone
        self.minWidth = minWidth
        self.showsRemoveButton = showsRemoveButton
        self.action = action
        self.onRemove = onRemove
    }

    public var body: some View {
        ZStack {
            Text(verbatim: title)
                .font(RCMTheme.shared.typography.captionStrong)
                .foregroundStyle(tone.foreground)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(maxWidth: .infinity, alignment: .center)

            HStack {
                Spacer(minLength: 0)
                removeButton
            }
        }
        .frame(minWidth: minWidth, alignment: .leading)
        .padding(.horizontal, RCMTheme.shared.spacing.sm)
        .padding(.vertical, RCMTheme.shared.spacing.xs)
        .background(tone.background)
        .overlay(
            Capsule()
                .stroke(tone.border, lineWidth: RCMTheme.shared.stroke.hairline)
        )
        .clipShape(Capsule())
        .contentShape(Capsule())
        .onTapGesture {
            action?()
        }
        .onHover { hovering in
            isHovering = hovering
        }
    }

    @ViewBuilder
    private var removeButton: some View {
        if showsRemoveButton {
            Button {
                onRemove?()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tone.foreground.opacity(0.72))
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            .disabled(onRemove == nil)
            .opacity(isHovering ? 1 : 0)
            .allowsHitTesting(isHovering)
            .animation(.easeInOut(duration: 0.12), value: isHovering)
        }
    }
}

// MARK: - RCMPillFlow

public enum RCMPillFlowSortOrder: Sendable {
    /// 保持调用方传入顺序。
    case original
    /// 按字符串本地化升序排序。
    case ascending
    /// 按字符串本地化降序排序。
    case descending
}

/// 流式 pill 标签列表。标签会按展示顺序轮换浅色背景，形成轻量的随机色效果。
public struct RCMPillFlow: View {
    let items: [String]
    let sortOrder: RCMPillFlowSortOrder
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat
    let minItemWidth: CGFloat?
    let palette: [RCMPillTone]
    let showsRemoveButton: Bool
    let onTap: ((String) -> Void)?
    let onRemove: ((String) -> Void)?

    public init(
        _ items: [String],
        sortOrder: RCMPillFlowSortOrder = .original,
        horizontalSpacing: CGFloat = RCMTheme.shared.spacing.sm,
        verticalSpacing: CGFloat = RCMTheme.shared.spacing.sm,
        minItemWidth: CGFloat? = nil,
        palette: [RCMPillTone] = RCMPillTone.defaultPalette,
        showsRemoveButton: Bool = false,
        onTap: ((String) -> Void)? = nil,
        onRemove: ((String) -> Void)? = nil
    ) {
        self.items = items
        self.sortOrder = sortOrder
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
        self.minItemWidth = minItemWidth
        self.palette = palette.isEmpty ? RCMPillTone.defaultPalette : palette
        self.showsRemoveButton = showsRemoveButton
        self.onTap = onTap
        self.onRemove = onRemove
    }

    public var body: some View {
        RCMFlowLayout(
            horizontalSpacing: horizontalSpacing,
            verticalSpacing: verticalSpacing
        ) {
            ForEach(Array(sortedItems.enumerated()), id: \.offset) { index, item in
                RCMPill(
                    item,
                    tone: tone(at: index),
                    minWidth: minItemWidth,
                    showsRemoveButton: showsRemoveButton,
                    action: onTap.map { handler in { handler(item) } },
                    onRemove: onRemove.map { handler in { handler(item) } }
                )
            }
        }
    }

    private var sortedItems: [String] {
        switch sortOrder {
        case .original:
            return items
        case .ascending:
            return items.sorted {
                $0.localizedStandardCompare($1) == .orderedAscending
            }
        case .descending:
            return items.sorted {
                $0.localizedStandardCompare($1) == .orderedDescending
            }
        }
    }

    private func tone(at index: Int) -> RCMPillTone {
        palette[index % palette.count]
    }
}
