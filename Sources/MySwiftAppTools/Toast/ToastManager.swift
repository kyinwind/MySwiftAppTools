
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

 7. 消息历史的可选配置（展示层与存储层分开两个方法，避免既有签名膨胀）：

    ToastManager.shared.configureToastHistory(
        maxCount: 500,
        isHistoryEnabled: true
    )

 说明：
 - 默认使用 ToastManager.shared，全局函数 ShowToast... 都写入 shared。
 - ToastView 只需要挂一次；没有挂 ToastView 时，调用 ShowToast 会更新状态但用户看不到 UI。
 - loading 和 requireConfirm 不会自动消失，需要手动确认或调用 ShowToastHide。
 - 点击非 success 类型 toast 会复制文本到剪贴板，copyOnTap 可关闭。
 - 每条 toast 都会写入消息历史（ToastHistoryStore），可用 ToastHistoryView 浏览和管理。
   默认最多保留 500 条、排除 loading 类型；开关与上限见 configureToastHistory(...)。
 */
public struct ToastItem: Identifiable, Equatable {
    public let id = UUID()
    public let message: String
    /// 消息发出时间。同时会写入消息历史（见 `ToastHistoryStore`）。
    public let createdAt: Date
    public let type: ToastType
    public let position: ToastPosition
    public let customIcon: Image?
    public let requireConfirm: Bool
    public let onConfirm: (() -> Void)?

    public static func == (lhs: ToastItem, rhs: ToastItem) -> Bool {
        lhs.id == rhs.id
    }
}

public enum ToastType: String, Codable, Sendable {
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

public enum ToastPosition: String, Codable, Sendable {
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

    /// 消息历史的配置入口，等价于对 `ToastHistoryStore.shared` 做**局部更新**。
    ///
    /// **省略的参数保持原值**，不会被重置。所以下面两次调用互不干扰：
    ///
    /// ```swift
    /// ToastManager.shared.configureToastHistory(maxCount: 2000)
    /// ToastManager.shared.configureToastHistory(isHistoryEnabled: false)
    /// // 结果：maxCount 仍是 2000，记录已关闭
    /// ```
    ///
    /// 想清空排除列表（恢复记录 `loading`）传空集即可：`excludedTypes: []`。
    /// 不传则是「保持原样」。
    ///
    /// - Note: `ToastHistoryStore` 不对外暴露配置写入。所有实例共用同一个 UserDefaults key，
    ///   多个实例各设一套策略会互相裁剪，因此策略变更只保留这一个公开入口。
    @MainActor
    public func configureToastHistory(
        maxCount: Int? = nil,
        isHistoryEnabled: Bool? = nil,
        excludedTypes: Set<ToastType>? = nil,
        maxMessageLength: Int? = nil,
        maxTotalBytes: Int? = nil,
        deferredPersist: Bool? = nil
    ) {
        let history = ToastHistoryStore.shared
        history.configure(
            maxCount: maxCount ?? history.maxCount,
            isHistoryEnabled: isHistoryEnabled ?? history.isHistoryEnabled,
            excludedTypes: excludedTypes ?? history.excludedTypes,
            maxMessageLength: maxMessageLength ?? history.maxMessageLength,
            maxTotalBytes: maxTotalBytes ?? history.maxTotalBytes,
            deferredPersist: deferredPersist ?? history.deferredPersist
        )
    }

    /// 消息历史存储的快捷入口，等价于 `ToastHistoryStore.shared`。
    ///
    /// 用于读取记录与做增删：`ToastManager.shared.toastHistory.records` / `.delete(_:)` / `.clearAll()`。
    public var toastHistory: ToastHistoryStore { .shared }

    /// `toastHistory` 的旧名，保留以兼容。
    public var history: ToastHistoryStore { .shared }

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
            createdAt: Date(),
            type: type,
            position: position,
            customIcon: customIcon,
            requireConfirm: requireConfirm,
            onConfirm: onConfirm
        )

        // 写入消息历史（受 isHistoryEnabled / excludedTypes 过滤）。
        // 与下方 toasts 数组完全独立：toast 定时消失或被挤出，都不影响历史记录。
        ToastHistoryStore.shared.record(item)

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
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)
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
