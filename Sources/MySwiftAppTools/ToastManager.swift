
#if os(macOS)
import AppKit
#endif

#if os(iOS)
import UIKit
#endif

import SwiftUI

/*
 Toast 全局提示工具。

 使用方式：

 1. 在 App 根视图加一次 ToastView：

    WindowGroup {
        ContentView()
            .overlay(ToastView())
    }

 2. 在任意 MainActor 上显示提示：

    ShowToast("普通提示")
    ShowToastSuccess("保存成功")
    ShowToastWarn("请先选择文件")
    ShowToastError("操作失败")

 3. 在异步任务或后台回调中调用：

    Task { @MainActor in
        ShowToastSuccess("处理完成")
    }

 4. 显示需要用户确认的提示：

    ShowToast(
        "首次使用需要确认",
        customIcon: Image(systemName: "sparkles"),
        requireConfirm: true,
        onConfirm: {
            // 用户点击 OK 后执行
        }
    )

 5. 显示 loading，并在任务结束后隐藏：

    ShowToast("处理中...", type: .loading)
    // ...
    ShowToastHide()

 6. 可选配置：

    ToastManager.shared.configure(
        maxVisibleToasts: 5,
        toastWidth: 420,
        topPadding: 50,
        bottomPadding: 50,
        copyOnTap: true
    )

 说明：
 - 默认使用 ToastManager.shared，全局函数 ShowToast... 都写入 shared。
 - ToastView 只需要挂一次；没有挂 ToastView 时，调用 ShowToast 会更新状态但用户看不到 UI。
 - loading 和 requireConfirm 不会自动消失，需要手动确认或调用 ShowToastHide。
 - 点击非 success 类型 toast 会复制文本到剪贴板，copyOnTap 可关闭。
 */
public struct ToastItem: Identifiable, Equatable {
    public let id = UUID()
    public let message: String
    public let type: ToastType
    public let position: ToastPosition
    public let customIcon: Image?
    public let requireConfirm: Bool
    public let onConfirm: (() -> Void)?

    public static func == (lhs: ToastItem, rhs: ToastItem) -> Bool {
        lhs.id == rhs.id
    }
}

public enum ToastType {
    case success
    case error
    case warning
    case loading
    case normal
}

extension ToastType {
    @ViewBuilder
    @MainActor
    var icon: some View {
        switch self {
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .green)
        case .error:
            Image(systemName: "xmark.octagon.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .red)
        case .warning:
            Image(systemName: "exclamationmark.triangle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .orange)
        case .loading:
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
        case .normal:
            Image(systemName: "info.circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .blue)
        }
    }

    var backgroundColor: Color {
        switch self {
        case .success: return .green.opacity(0.7)
        case .error: return .red.opacity(0.7)
        case .warning: return .orange.opacity(0.7)
        case .loading: return .gray.opacity(0.7)
        case .normal: return .blue.opacity(0.7)
        }
    }
}

public enum ToastPosition {
    case top
    case bottom
}

@MainActor
@Observable
public final class ToastManager {
    public static let shared = ToastManager()

    public private(set) var toasts: [ToastItem] = []

    public var maxVisibleToasts = 7
    public var toastWidth: CGFloat = 420
    public var topPadding: CGFloat = 50
    public var bottomPadding: CGFloat = 50
    public var copyOnTap = true

    public init() {}

    public func configure(
        maxVisibleToasts: Int = 7,
        toastWidth: CGFloat = 420,
        topPadding: CGFloat = 50,
        bottomPadding: CGFloat = 50,
        copyOnTap: Bool = true
    ) {
        self.maxVisibleToasts = max(1, maxVisibleToasts)
        self.toastWidth = max(240, toastWidth)
        self.topPadding = topPadding
        self.bottomPadding = bottomPadding
        self.copyOnTap = copyOnTap
    }

    public func show(
        _ text: String,
        type: ToastType = .normal,
        duration: TimeInterval = 2,
        position: ToastPosition = .top,
        customIcon: Image? = nil,
        requireConfirm: Bool = false,
        onConfirm: (() -> Void)? = nil
    ) {
        let item = ToastItem(
            message: text,
            type: type,
            position: position,
            customIcon: customIcon,
            requireConfirm: requireConfirm,
            onConfirm: onConfirm
        )

        withAnimation {
            toasts.append(item)
            trimToLimit()
        }

        if !item.requireConfirm && item.type != .loading {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(duration))
                remove(item)
            }
        }
    }

    public func remove(_ item: ToastItem) {
        withAnimation {
            toasts.removeAll { $0.id == item.id }
        }
    }

    public func hideAll() {
        withAnimation {
            toasts.removeAll()
        }
    }

    private func trimToLimit() {
        guard toasts.count > maxVisibleToasts else { return }
        toasts.removeFirst(toasts.count - maxVisibleToasts)
    }
}

@MainActor
private func copyToPasteboard(_ text: String) {
    #if os(macOS)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
    NSSound(named: NSSound.Name("Glass"))?.play()
    #elseif os(iOS)
    UIPasteboard.general.string = text
    let generator = UINotificationFeedbackGenerator()
    generator.notificationOccurred(.success)
    #endif

    ShowToastSuccess(MySwiftAppToolsL10n.copiedToPasteboard.toPackageNSLocalizedString)
}

public struct ToastView: View {
    @State private var manager: ToastManager

    public init(manager: ToastManager = .shared) {
        self.manager = manager
    }

    public var body: some View {
        ZStack {
            VStack(spacing: 10) {
                ForEach(manager.toasts.filter { $0.position == .top }) { item in
                    ToastRow(item: item, manager: manager) { text in
                        copyToPasteboard(text)
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()
                    .allowsHitTesting(false)
            }
            .padding(.top, manager.topPadding)
            .padding(.horizontal, 10)

            VStack(spacing: 10) {
                Spacer()
                ForEach(manager.toasts.filter { $0.position == .bottom }) { item in
                    ToastRow(item: item, manager: manager) { text in
                        copyToPasteboard(text)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.bottom, manager.bottomPadding)
            .padding(.horizontal, 10)
        }
        .animation(.easeInOut, value: manager.toasts)
    }
}

private struct ToastRow: View {
    let item: ToastItem
    let manager: ToastManager
    let onCopy: (String) -> Void

    @State private var isHovering = false

    @ViewBuilder
    private var iconView: some View {
        if let customIcon = item.customIcon {
            customIcon
        } else {
            item.type.icon
        }
    }

    private var showCopyButton: Bool {
        #if os(macOS)
        return isHovering && manager.copyOnTap
        #else
        return manager.copyOnTap
        #endif
    }

    private var copyButton: some View {
        Button {
            onCopy(item.message)
        } label: {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white.opacity(0.8))
                .padding(6)
                .background(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.15))
                )
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    var body: some View {
        HStack(spacing: 12) {
            iconView

            Text(item.message)
                .foregroundColor(.white)
                .font(.system(size: 15, weight: .semibold))
                .multilineTextAlignment(.leading)
                .lineLimit(10)
                .truncationMode(.tail)

            Spacer()

            if item.requireConfirm {
                Button(MySwiftAppToolsL10n.confirmOK.toPackageNSLocalizedString) {
                    manager.remove(item)
                    item.onConfirm?()
                }
                .buttonStyle(.borderedProminent)
            } else if manager.copyOnTap {
                copyButton
                    .opacity(showCopyButton ? 1 : 0)
                    .animation(.easeInOut(duration: 0.15), value: isHovering)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(item.type.backgroundColor)
        .cornerRadius(14)
        .frame(width: manager.toastWidth, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .onTapGesture {
            guard manager.copyOnTap, item.type != .success else { return }
            onCopy(item.message)
        }
        #if os(macOS)
        .onHover { hovering in
            isHovering = hovering
        }
        #endif
    }
}

@MainActor
public func ShowToast(
    _ text: String,
    type: ToastType = .normal,
    duration: TimeInterval = 3,
    position: ToastPosition = .top,
    customIcon: Image? = nil,
    requireConfirm: Bool = false,
    onConfirm: (() -> Void)? = nil
) {
    ToastManager.shared.show(
        text,
        type: type,
        duration: duration,
        position: position,
        customIcon: customIcon,
        requireConfirm: requireConfirm,
        onConfirm: onConfirm
    )
}

@MainActor
public func ShowToastSuccess(
    _ text: String,
    type: ToastType = .success,
    duration: TimeInterval = 3,
    position: ToastPosition = .top
) {
    ToastManager.shared.show(text, type: type, duration: duration, position: position)
}

@MainActor
public func ShowToastError(
    _ text: String,
    type: ToastType = .error,
    duration: TimeInterval = 7,
    position: ToastPosition = .top
) {
    ToastManager.shared.show(text, type: type, duration: duration, position: position)
}

@MainActor
public func ShowToastWarn(
    _ text: String,
    type: ToastType = .warning,
    duration: TimeInterval = 3,
    position: ToastPosition = .top
) {
    ToastManager.shared.show(text, type: type, duration: duration, position: position)
}

@MainActor
public func ShowToastHide() {
    ToastManager.shared.hideAll()
}
