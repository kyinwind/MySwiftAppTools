//
//  MultiSourceDownloader.swift
//  MySwiftAppTools
//
//  Created by yangxuehui on 2026/5/12.
//

import Foundation
import CryptoKit

/// ⚠️ 必须在主项目或包的 Build Settings 中将 Swift Language Version 设为 5.5 或以上。
public final class MultiSourceDownloader: NSObject ,@unchecked Sendable {
    
    // MARK: - Types
    
    public enum DownloadError: Error, LocalizedError {
        case noValidUrls
        case allSourcesFailed
        case verificationFailed
        case invalidResponse
        
        public var errorDescription: String? {
            switch self {
            case .noValidUrls: return "所有提供的链接都无法访问。"
            case .allSourcesFailed: return "尝试了所有链接及重试机会，下载全部失败。"
            case .verificationFailed: return "文件下载成功，但 SHA256 校验未通过。"
            case .invalidResponse: return "服务器返回了无效的响应。"
            }
        }
    }
    
    // MARK: - Properties
    
    public let urls: [URL]
    public let expectedSHA256: String?
    public let destinationURL: URL
    
    // 最大重试配置
    private let maxRetryCount = 3
    
    private let fileManager = FileManager.default
    private var session: URLSession!
    
    // 下载状态追踪
    private var currentTask: URLSessionDataTask?
    private var fileHandle: FileHandle?
    private var currentDownloadedBytes: Int64 = 0
    private var totalExpectedBytes: Int64 = 0
    private var onProgress: (@Sendable (Double) -> Void)?
    
    private let queue = DispatchQueue(label: "com.downloader.queue")
    private var continuation: CheckedContinuation<Void, Error>?
    
    // MARK: - Initialization
    
    /// 初始化下载器
    /// - Parameters:
    ///   - urls: 下载链接数组（应按优先级排序，例如国内用户首位放魔塔，国外放 GitHub）
    ///   - destinationURL: 本地保存的目标文件路径
    ///   - expectedSHA256: 可选的 SHA256 校验码（Hex 字符串）
    public init(urls: [URL], destinationURL: URL, expectedSHA256: String? = nil) {
        self.urls = urls
        self.destinationURL = destinationURL
        self.expectedSHA256 = expectedSHA256
        super.init()
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15.0
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    
    // MARK: - Public Methods
    
    /// 开始执行下载流程（包含可用性检测、带重试的断点续传轮询、SHA256 校验）
    /// - Parameter progress: 进度回调闭包（返回 0.0 到 1.0 的浮点数）
    public func startDownload(progress: @escaping @Sendable (Double) -> Void) async throws {
        self.onProgress = progress
        
        // 1. 并发检测所有链接的可访问性
        let accessibleUrls = await filterAccessibleUrls(from: self.urls)
        guard !accessibleUrls.isEmpty else {
            throw DownloadError.noValidUrls
        }
        
        // 2. 依次尝试可用的链接进行断点续传下载
        var downloadSuccess = false
        for url in accessibleUrls {
            var retryAttempt = 0
            
            while retryAttempt < maxRetryCount {
                do {
                    try await performDownload(from: url)
                    downloadSuccess = true
                    break // 下载成功，跳出重试循环
                } catch {
                    retryAttempt += 1
                    cleanTemporaryState()
                    
                    // 如果单条链接未达到重试上限，等待一段时间后再次尝试（指数退避机制）
                    if retryAttempt < maxRetryCount {
                        let delaySeconds = pow(2.0, Double(retryAttempt)) // 2s, 4s
                        try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
                    }
                }
            }
            
            if downloadSuccess {
                break // 已成功下载，跳出链接轮询循环
            }
        }
        
        guard downloadSuccess else {
            throw DownloadError.allSourcesFailed
        }
        
        // 3. 文件完整性校验
        if let expectedHash = expectedSHA256 {
            let isValid = verifySHA256(for: destinationURL, expected: expectedHash)
            if !isValid {
                try? fileManager.removeItem(at: destinationURL)
                throw DownloadError.verificationFailed
            }
        }
    }
    
    /// 显式取消当前下载任务
    public func cancel() {
        queue.async {
            self.currentTask?.cancel()
            self.cleanTemporaryState()
            self.continuation?.resume(throwing: CancellationError())
            self.continuation = nil
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// 核心下载逻辑（支持断点续传）
    private func performDownload(from url: URL) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            self.queue.async {
                self.continuation = continuation
                
                // 检查本地已存在的文件大小（用于断点续传）
                if self.fileManager.fileExists(atPath: self.destinationURL.path) {
                    let attributes = try? self.fileManager.attributesOfItem(atPath: self.destinationURL.path)
                    self.currentDownloadedBytes = attributes?[.size] as? Int64 ?? 0
                } else {
                    self.fileManager.createFile(atPath: self.destinationURL.path, contents: nil, attributes: nil)
                    self.currentDownloadedBytes = 0
                }
                
                var request = URLRequest(url: url)
                if self.currentDownloadedBytes > 0 {
                    // 设置断点续传请求头
                    request.setValue("bytes=\(self.currentDownloadedBytes)-", forHTTPHeaderField: "Range")
                }
                
                self.fileHandle = try? FileHandle(forWritingTo: self.destinationURL)
                if let fileHandle = self.fileHandle {
                    try? fileHandle.seek(toOffset: UInt64(self.currentDownloadedBytes))
                }
                
                let task = self.session.dataTask(with: request)
                self.currentTask = task
                task.resume()
            }
        }
    }
    
    /// 并发检测链接是否可用 (HEAD 请求避免下载内容)
    private func filterAccessibleUrls(from sourceUrls: [URL]) async -> [URL] {
        await withTaskGroup(of: (URL, Bool).self) { group in
            for url in sourceUrls {
                group.addTask {
                    var request = URLRequest(url: url)
                    request.httpMethod = "HEAD"
                    request.timeoutInterval = 5.0 // 快速超时设定
                    do {
                        let (_, response) = try await URLSession.shared.data(for: request)
                        if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                            return (url, true)
                        }
                    } catch {}
                    return (url, false)
                }
            }
            
            var validUrls: [URL] = []
            for await (url, isAccessible) in group {
                if isAccessible { validUrls.append(url) }
            }
            // 保持原始传入的相对先后顺序
            return sourceUrls.filter { validUrls.contains($0) }
        }
    }
    
    /// SHA256 流式校验（避免大文件直接加载进内存导致崩盘）
    private func verifySHA256(for fileURL: URL, expected: String) -> Bool {
        guard let fileHandle = try? FileHandle(forReadingFrom: fileURL) else { return false }
        defer { try? fileHandle.close() }
        
        var hasher = SHA256()
        let bufferSize = 64 * 1024 // 64KB 缓冲区
        
        while true {
            guard let data = try? fileHandle.read(upToCount: bufferSize), !data.isEmpty else { break }
            hasher.update(data: data)
        }
        
        let digest = hasher.finalize()
        let hashString = digest.map { String(format: "%02hhx", $0) }.joined()
        return hashString.lowercased() == expected.lowercased()
    }
    
    private func cleanTemporaryState() {
        try? fileHandle?.close()
        fileHandle = nil
        currentTask = nil
    }
}

// MARK: - URLSessionDataDelegate

extension MultiSourceDownloader: URLSessionDataDelegate {
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let httpResponse = response as? HTTPURLResponse else {
            completionHandler(.cancel)
            return
        }
        
        queue.async {
            let statusCode = httpResponse.statusCode
            
            if statusCode == 206 {
                // 206 Partial Content: 正确响应了断点续传
                let contentRange = httpResponse.value(forHTTPHeaderField: "Content-Range")
                if let totalStr = contentRange?.components(separatedBy: "/").last, let total = Int64(totalStr) {
                    self.totalExpectedBytes = total
                }
            } else if statusCode == 200 {
                // 200 OK: 服务器不支持断点续传，重置本地文件并重新开始
                self.currentDownloadedBytes = 0
                try? self.fileHandle?.seek(toOffset: 0)
                try? self.fileHandle?.truncate(atOffset: 0)
                self.totalExpectedBytes = httpResponse.expectedContentLength
            } else {
                // 其他异常状态码，拒收数据
                completionHandler(.cancel)
                return
            }
            completionHandler(.allow)
        }
    }
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        queue.async {
            guard let fileHandle = self.fileHandle else { return }
            
            try? fileHandle.write(contentsOf: data)
            self.currentDownloadedBytes += Int64(data.count)
            
            if self.totalExpectedBytes > 0 {
                let progressPercentage = Double(self.currentDownloadedBytes) / Double(self.totalExpectedBytes)
                DispatchQueue.main.async {
                    self.onProgress?(progressPercentage)
                }
            }
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        queue.async {
            defer { self.cleanTemporaryState() }
            
            if let error = error {
                self.continuation?.resume(throwing: error)
            } else {
                self.continuation?.resume()
            }
            self.continuation = nil
        }
    }
}
