//
//  FeedbackManager.swift
//  MySwiftAppTools
//
//  Created by yangxuehui on 2026/5/16.
//

import SwiftUI
import Foundation
import Combine
import AppKit
import UniformTypeIdentifiers

// MARK: - Configuration

public struct FeedbackConfiguration {
    public let appleID: String
    public let supportURL: String
    public let email: String
    public let discordWebhook: String
    public let dingTalkWebhook: String
    public var appName: String?

    public static let defaultEmail = "yangxuehui@outlook.com"
    public static let defaultDiscordWebhook = "https://discord.com/api/webhooks/1480084428188549174/gROlu7EzQdVS1icNZD1_3AirLfHtoTCumEPzD_P66rFt6Bv4CaZmA1NwfEjTuJip67Ro"
    public static let defaultDingTalkWebhook = "https://oapi.dingtalk.com/robot/send?access_token=fe7f86d6c40a7585ead48d4c87cbbdbbb49b96171c0c8fc6a3ef0f72ec2ae0c2"

    public init(
        appleID: String,
        supportURL: String,
        email: String = Self.defaultEmail,
        discordWebhook: String = Self.defaultDiscordWebhook,
        dingTalkWebhook: String = Self.defaultDingTalkWebhook,
        appName: String? = nil
    ) {
        self.appleID = appleID
        self.supportURL = supportURL
        self.email = email
        self.discordWebhook = discordWebhook
        self.dingTalkWebhook = dingTalkWebhook
        self.appName = appName
    }
}

// MARK: - Channel & Payload

public enum FeedbackChannel: String, Hashable, CaseIterable {
    case discord
    case dingTalk
    case mail

    public var displayName: String {
        switch self {
        case .discord: return packageL("FeedbackView.type.discord")
        case .dingTalk: return packageL("FeedbackView.type.dingding")
        case .mail: return packageL("FeedbackView.type.mail")
        }
    }
}

public struct FeedbackPayload {
    public var content: String
    public var attachments: [URL]
    public var includeSystemInfo: Bool
    public var systemInfo: String?
    public var channels: [FeedbackChannel]

    public init(
        content: String,
        attachments: [URL] = [],
        includeSystemInfo: Bool = true,
        systemInfo: String? = nil,
        channels: [FeedbackChannel] = [.discord]
    ) {
        self.content = content
        self.attachments = attachments
        self.includeSystemInfo = includeSystemInfo
        self.systemInfo = systemInfo
        self.channels = channels
    }
}

// MARK: - AppStoreHelper

public struct AppStoreHelper {
    /// 打开 Mac App Store 评分页面
    public static func rateApp(appleID: String) {
        let urlString = "macappstore://itunes.apple.com/app/id\(appleID)?action=write-review"
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}

// MARK: - System Info

public struct SystemInfoProvider {
    /// 收集应用和系统信息，用于附加到反馈中
    public static func collect(appName: String? = nil) -> String {
        let name = appName ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "UnknownApp")
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"

        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        let systemVersion = "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"

        let cpuType = HardwareInfo.cpuType()
        let locale = Locale.current.identifier

        return """
        App: \(name)
        Version: \(version) (\(build))
        System: macOS \(systemVersion)
        CPU: \(cpuType)
        Locale: \(locale)
        """
    }
}

public struct HardwareInfo {
    public static func cpuArchitecture() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        return mirror.children.reduce("") { acc, element in
            guard let value = element.value as? Int8, value != 0 else { return acc }
            return acc + String(UnicodeScalar(UInt8(value)))
        }
    }

    public static func cpuType() -> String {
        let arch = cpuArchitecture()
        if arch.contains("arm") || arch.contains("arm64") {
            return "Apple Silicon (ARM64)"
        }
        if arch.contains("x86") {
            return "Intel (x86_64)"
        }
        return arch
    }
}

// MARK: - FeedbackManager

@MainActor
public final class FeedbackManager: ObservableObject {
    public static let shared = FeedbackManager()
    private init() {}

    public private(set) var config: FeedbackConfiguration?

    /// 配置反馈管理器。必须在调用 sendFeedback 或使用 FeedbackView 之前调用。
    ///
    /// - Parameters:
    ///   - appleID: Mac App Store 的应用 ID，用于「给应用评分」功能
    ///   - supportURL: 技术支持页面的 URL
    ///   - email: 接收反馈的邮箱地址，默认使用 `FeedbackConfiguration.defaultEmail`
    ///   - discordWebhook: Discord Webhook URL，默认使用 `FeedbackConfiguration.defaultDiscordWebhook`
    ///   - dingTalkWebhook: 钉钉机器人 Webhook URL，默认使用 `FeedbackConfiguration.defaultDingTalkWebhook`
    ///   - appName: 应用名称（可选），用于系统信息收集
    public func configure(
        appleID: String,
        supportURL: String,
        email: String = FeedbackConfiguration.defaultEmail,
        discordWebhook: String = FeedbackConfiguration.defaultDiscordWebhook,
        dingTalkWebhook: String = FeedbackConfiguration.defaultDingTalkWebhook,
        appName: String? = nil
    ) {
        config = FeedbackConfiguration(
            appleID: appleID,
            supportURL: supportURL,
            email: email,
            discordWebhook: discordWebhook,
            dingTalkWebhook: dingTalkWebhook,
            appName: appName
        )
    }

    public var isConfigured: Bool { config != nil }

    @Published public var isSending: Bool = false

    private var webhooks: [FeedbackChannel: String] {
        guard let config else { return [:] }
        return [
            .discord: config.discordWebhook,
            .dingTalk: config.dingTalkWebhook,
            .mail: config.email
        ]
    }

    /// 发送反馈到指定的渠道。如果配置了多个渠道，会依次发送，全部失败才抛出错误。
    public func sendFeedback(_ feedback: FeedbackPayload) async throws {
        guard let config else {
            throw FeedbackError.notConfigured
        }

        await MainActor.run { isSending = true }
        defer { Task { @MainActor in isSending = false } }

        var lastError: Error?

        for channel in feedback.channels {
            guard let urlString = webhooks[channel], let url = URL(string: urlString) else { continue }

            do {
                switch channel {
                case .discord:
                    try await sendToDiscord(url: url, payload: feedback)
                case .dingTalk:
                    try await sendToDingTalk(url: url, payload: feedback)
                case .mail:
                    try await sendToMail(config: config, payload: feedback)
                }
            } catch {
                lastError = error
            }
        }

        if let error = lastError {
            throw error
        }
    }

    // MARK: - Channel Implementations

    private func sendToMail(config: FeedbackConfiguration, payload: FeedbackPayload) async throws {
        var contentText = payload.content
        if payload.includeSystemInfo, let sys = payload.systemInfo {
            contentText += "\n\n\(packageL("FeedbackManager.sysInfo")):\n\(sys)"
        }

        let subject = "App Feedback"
        let bodyEncoded = contentText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let subjectEncoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let mailto = "mailto:\(config.email)?subject=\(subjectEncoded)&body=\(bodyEncoded)"

        if let url = URL(string: mailto) {
            _ = await MainActor.run {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func sendToDiscord(url: URL, payload: FeedbackPayload) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        if payload.attachments.isEmpty {
            var contentText = payload.content
            if payload.includeSystemInfo, let sys = payload.systemInfo {
                contentText += "\n\n\(packageL("FeedbackManager.sysInfo")):\n\(sys)"
            }
            let jsonDict: [String: Any] = ["content": contentText]
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: jsonDict)

            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResp = response as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) else {
                throw FeedbackError.discordWebhookFailed
            }
        } else {
            let boundary = "Boundary-\(UUID().uuidString)"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            request.httpBody = try createMultipartBody(payload: payload, boundary: boundary)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResp = response as? HTTPURLResponse else {
                throw FeedbackError.discordRequestFailed
            }
            guard (200...299).contains(httpResp.statusCode) else {
                let errorText = String(data: data, encoding: .utf8) ?? "unknown error"
                throw FeedbackError.discordUploadFailed(statusCode: httpResp.statusCode, message: errorText)
            }
        }
    }

    private func sendToDingTalk(url: URL, payload: FeedbackPayload) async throws {
        var contentText = "feedback\n" + payload.content
        if payload.includeSystemInfo, let sys = payload.systemInfo {
            contentText += "\n\n\(packageL("FeedbackManager.sysInfo")):\n\(sys)"
        }
        let jsonDict: [String: Any] = ["msgtype": "text", "text": ["content": contentText]]
        let data = try JSONSerialization.data(withJSONObject: jsonDict)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResp = response as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) else {
            throw FeedbackError.dingTalkFailed
        }
    }

    // MARK: - Multipart Helpers

    private func createMultipartBody(payload: FeedbackPayload, boundary: String) throws -> Data {
        var body = Data()

        var contentText = payload.content
        if payload.includeSystemInfo, let sys = payload.systemInfo {
            contentText += "\n\n\(packageL("FeedbackManager.sysInfo")):\n\(sys)"
        }

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"content\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(contentText)\r\n".data(using: .utf8)!)

        for (i, fileURL) in payload.attachments.enumerated() {
            let fileData = try Data(contentsOf: fileURL)
            let filename = fileURL.lastPathComponent
            let mimeType = mimeTypeFor(url: fileURL)

            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\(i)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
            body.append(fileData)
            body.append("\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return body
    }

    private func mimeTypeFor(url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "txt", "log": return "text/plain"
        default: return "application/octet-stream"
        }
    }
}

// MARK: - Errors

public enum FeedbackError: LocalizedError {
    case notConfigured
    case discordWebhookFailed
    case discordRequestFailed
    case discordUploadFailed(statusCode: Int, message: String)
    case dingTalkFailed

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return packageL("FeedbackManager.notConfigured")
        case .discordWebhookFailed:
            return packageL("FeedbackManager.discordWebhookFailed")
        case .discordRequestFailed:
            return packageL("FeedbackManager.discordRequestFailed")
        case .discordUploadFailed(_, let message):
            return "\(packageL("FeedbackManager.discordUploadFailed")): \(message)"
        case .dingTalkFailed:
            return packageL("FeedbackManager.dingTalkFailed")
        }
    }
}

// MARK: - FeedbackView

public struct FeedbackView: View {
    @State private var content: String = ""
    @State private var selectedChannel: FeedbackChannel = .mail
    @State private var images: [NSImage] = []
    @State private var includeSystemInfo: Bool = true
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""

    @ObservedObject private var manager = FeedbackManager.shared

    private var systemInfo: String {
        SystemInfoProvider.collect(appName: FeedbackManager.shared.config?.appName)
    }

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(packageL("FeedbackView.title")).font(.title)

                // 评分 & 技术支持
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Button(packageL("FeedbackView.rate")) {
                            guard let config = FeedbackManager.shared.config else { return }
                            AppStoreHelper.rateApp(appleID: config.appleID)
                        }
                        if let config = FeedbackManager.shared.config {
                            Button {
                                if let url = URL(string: config.supportURL) {
                                    NSWorkspace.shared.open(url)
                                }
                            } label: {
                                Text(packageL("FeedbackView.techSupport"))
                                Text(config.supportURL)
                                    .foregroundColor(.blue)
                            }
                        }
                        Spacer()
                    }
                }
                .padding()

                // 反馈表单
                VStack(alignment: .leading, spacing: 12) {
                    if let channels = FeedbackManager.shared.config.map({ _ in FeedbackChannel.allCases }) {
                        Picker(packageL("FeedbackView.pickerTitle"), selection: $selectedChannel) {
                            ForEach(channels, id: \.self) { channel in
                                Text(channel.displayName).tag(channel)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                    }

                    MyTextView(
                        text: $content,
                        placeholder: packageL("FeedbackView.input"),
                        maxLength: 1700
                    )
                    .padding(12)
                    .frame(height: 150)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.4))
                    )
                    .padding(.horizontal)

                    Text(packageL("FeedbackView.followup"))
                        .font(.footnote)
                        .padding(.horizontal)

                    // 系统信息选项
                    HStack {
                        Toggle(isOn: $includeSystemInfo) {
                            Text(packageL("FeedbackView.sysinfo"))
                        }
                        .padding(.horizontal)
                        if includeSystemInfo {
                            Text(systemInfo)
                                .font(.footnote)
                                .foregroundColor(.gray)
                        }
                    }

                    // Discord 截图上传
                    if selectedChannel == .discord {
                        ScrollView(.horizontal) {
                            HStack {
                                addButton
                                ForEach(images.indices, id: \.self) { index in
                                    ZStack(alignment: .topTrailing) {
                                        Image(nsImage: images[index])
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 70, height: 70)
                                            .clipped()
                                            .cornerRadius(6)

                                        Button {
                                            images.remove(at: index)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                        }
                                        .offset(x: 6, y: -6)
                                    }
                                }
                            }
                        }
                        .frame(height: 80)
                    }
                }

                // 发送按钮
                Button(action: sendFeedbackAction) {
                    if manager.isSending {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(packageL("FeedbackView.sendFeedback"))
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .alert(alertMessage, isPresented: $showAlert) {
                Button(packageL("FeedbackView.ok")) {}
            }
        }
    }

    // MARK: - Image Picker

    private var addButton: some View {
        Button {
            selectScreenshot()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.gray)
                Image(systemName: "plus")
            }
            .frame(width: 70, height: 70)
        }
        .disabled(images.count >= 5)
    }

    private func selectScreenshot() {
        guard images.count < 5 else { return }

        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true

        if panel.runModal() == .OK {
            for url in panel.urls.prefix(5 - images.count) {
                if let image = NSImage(contentsOf: url) {
                    images.append(image)
                }
            }
        }
    }

    // MARK: - Send

    private func sendFeedbackAction() {
        var attachments: [URL] = []

        for image in images {
            if let tiff = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiff),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString + ".png")
                try? pngData.write(to: url)
                attachments.append(url)
            }
        }

        let payload = FeedbackPayload(
            content: content,
            attachments: attachments,
            includeSystemInfo: includeSystemInfo,
            systemInfo: systemInfo,
            channels: [selectedChannel]
        )

        Task {
            do {
                try await FeedbackManager.shared.sendFeedback(payload)
                alertMessage = packageL("FeedbackView.sendSuccess") + " ✔️"
            } catch {
                alertMessage = packageL("FeedbackView.sendFail") + " ❌ \(error.localizedDescription)"
            }
            showAlert = true
        }
    }
}

// MARK: - MyTextView

/// 为解决 TextEditor 文字被截的问题而自定义的 NSTextView 封装
public struct MyTextView: NSViewRepresentable {
    @Binding public var text: String
    public var placeholder: String = ""
    public var maxLength: Int?

    public init(text: Binding<String>, placeholder: String = "", maxLength: Int? = nil) {
        self._text = text
        self.placeholder = placeholder
        self.maxLength = maxLength
    }

    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.font = NSFont.systemFont(ofSize: 16)
        textView.backgroundColor = NSColor.clear
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true

        textView.textContainer?.containerSize = NSSize(
            width: scrollView.bounds.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.textContainer?.lineFragmentPadding = 0

        scrollView.documentView = textView

        // placeholder
        let placeholderLabel = NSTextField(labelWithString: placeholder)
        placeholderLabel.textColor = NSColor.placeholderTextColor
        placeholderLabel.font = textView.font
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.isHidden = !text.isEmpty

        textView.addSubview(placeholderLabel)

        NSLayoutConstraint.activate([
            placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 6),
            placeholderLabel.topAnchor.constraint(equalTo: textView.topAnchor, constant: 6)
        ])

        context.coordinator.textView = textView
        context.coordinator.placeholderLabel = placeholderLabel

        return scrollView
    }

    public func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        context.coordinator.updatePlaceholder()
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MyTextView
        weak var textView: NSTextView?
        weak var placeholderLabel: NSTextField?

        init(_ parent: MyTextView) {
            self.parent = parent
        }

        public func textView(
            _ textView: NSTextView,
            shouldChangeTextIn affectedCharRange: NSRange,
            replacementString: String?
        ) -> Bool {
            guard let maxLength = parent.maxLength else { return true }
            let currentText = textView.string
            let replacement = replacementString ?? ""
            guard let range = Range(affectedCharRange, in: currentText) else { return true }
            return currentText.replacingCharacters(in: range, with: replacement).count <= maxLength
        }

        public func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            updatePlaceholder()
        }

        @MainActor func updatePlaceholder() {
            placeholderLabel?.isHidden = !(textView?.string.isEmpty ?? true)
        }
    }
}

// MARK: - Preview

#Preview {
    FeedbackManager.shared.configure(
        appleID: "123456789",
        supportURL: "https://example.com/support"
    )
    return FeedbackView()
}
