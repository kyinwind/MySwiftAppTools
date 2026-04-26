
#if os(macOS)
import AppKit
#endif

#if os(iOS)
import UIKit
#endif

import SwiftUI

struct ToastItem: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let type: ToastType
    let position: ToastPosition
    // ✅ 新增
    let customIcon: Image?
    let requireConfirm: Bool
    let onConfirm: (() -> Void)?
    // 手动实现 Equatable，只比较 id
    static func == (lhs: ToastItem, rhs: ToastItem) -> Bool {
        return lhs.id == rhs.id
    }
}

enum ToastType {
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

enum ToastPosition {
    case top
    case bottom
}

@MainActor
@Observable
class ToastManager {

    static let shared = ToastManager()

    private(set) var toasts: [ToastItem] = []

    private init() {}

    func show(
        _ text: String,
        type: ToastType = .normal,
        duration: TimeInterval = 2,
        position: ToastPosition = .top,
        // ✅ 新增参数
        customIcon: Image? = nil,
        requireConfirm: Bool = false,
        onConfirm: (() -> Void)? = nil // 新增
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
        }

        // 限制最大数量（防止刷爆）
        if toasts.count > 7 {
            toasts.removeFirst()
        }

        // loading 不自动消失
        if !item.requireConfirm && item.type != .loading {
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                self.remove(item)
            }
        }
    }

    func remove(_ item: ToastItem) {
        withAnimation {
            toasts.removeAll { $0.id == item.id }
        }
    }

    func hideAll() {
        withAnimation {
            toasts.removeAll()
        }
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

    ShowToastSuccess(MySwiftAppToolsL10n.copiedToPasteboard.toNSLocalizedString)
}

struct ToastView: View {

    @State private var manager = ToastManager.shared
    
    var body: some View {

        ZStack {

            // TOP
            VStack(spacing: 10) {
                ForEach(manager.toasts.filter { $0.position == .top }) { item in
                    ToastRow(item: item) { text in
                        copyToPasteboard(text)
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()
                    .allowsHitTesting(false)
            }
            .padding(.top, 50)
            .padding(.horizontal, 10)

            // BOTTOM
            VStack(spacing: 10) {
                Spacer()
                ForEach(manager.toasts.filter { $0.position == .bottom }) { item in
                    toastContent(item)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        
                }
            }
            .padding(.bottom, 50)
            .padding(.horizontal, 10)
        }
        .animation(.easeInOut, value: manager.toasts)
        //.allowsHitTesting(false)
    }

    @ViewBuilder
    private func toastContent(_ item: ToastItem) -> some View {
        HStack(spacing: 10) {
            item.type.icon
            Text(item.message)
                .foregroundColor(.white)
                .font(.system(size: 15, weight: .semibold))
                .multilineTextAlignment(.leading)
                .lineLimit(5)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(item.type.backgroundColor)
        .cornerRadius(12)
        .frame(width: 420, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .onTapGesture {
            if item.type != .success {
                copyToPasteboard(item.message)
            }
        }
    }
}

struct ToastRow: View {

    let item: ToastItem
    let onCopy: (String) -> Void

    @State private var isHovering = false
    var iconView: some View {
        if let customIcon = item.customIcon {
            AnyView(customIcon)
        } else {
            AnyView(item.type.icon)
        }
    }
    private var showCopyButton: Bool {
        #if os(macOS)
        return isHovering
        #else
        return true
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
                Button(MySwiftAppToolsL10n.confirmOK.toNSLocalizedString) {
                    ToastManager.shared.remove(item)
                    // 调用回调
                    item.onConfirm?()
                }
                .buttonStyle(.borderedProminent)
            }else{
                copyButton
                    .opacity(showCopyButton ? 1 : 0)
                    .animation(.easeInOut(duration: 0.15), value: isHovering)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(item.type.backgroundColor)
        .cornerRadius(14)
        .frame(width: 420, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .trailing)
        #if os(macOS)
        .onHover { hovering in
            isHovering = hovering
        }
        #endif
    }
}

// ✅ 对外接口：一行调用
@MainActor
func ShowToast(
    _ text: String,
    type: ToastType = .normal,
    duration: TimeInterval = 3,
    position: ToastPosition = .top,
    
    // ✅ 新增
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
func ShowToastSuccess(
    _ text: String,
    type: ToastType = .success,
    duration: TimeInterval = 3,
    position: ToastPosition = .top
) {
    ToastManager.shared.show(text, type: type, duration: duration, position: position)
}
@MainActor
func ShowToastError(
    _ text: String,
    type: ToastType = .error,
    duration: TimeInterval = 7,
    position: ToastPosition = .top
) {
    ToastManager.shared.show(text, type: type, duration: duration, position: position)
}
@MainActor
func ShowToastWarn(
    _ text: String,
    type: ToastType = .warning,
    duration: TimeInterval = 3,
    position: ToastPosition = .top
) {
    ToastManager.shared.show(text, type: type, duration: duration, position: position)
}
@MainActor
func ShowToastHide() {
    ToastManager.shared.hideAll()
}
