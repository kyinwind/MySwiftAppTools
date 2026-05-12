import Foundation
import CryptoKit

/// ⚠️ 必须在主项目或包的 Build Settings 中将 Swift Language Version 设为 5.5 或以上。
public final class MultiSourceDownloader: NSObject, @unchecked Sendable {
    
    // MARK: - Types
    public enum DownloadError: Error, LocalizedError {
        case noValidUrls
        case allSourcesFailed
        case verificationFailed
        case invalidResponse
        case fileAlreadyExists // 新增：防止临时文件冲突
        
        public var errorDescription: String? {
            switch self {
            case .noValidUrls: return "所有提供的链接都无法访问。"
            case .allSourcesFailed: return "尝试了所有链接及重试机会，下载全部失败。"
            case .verificationFailed: return "文件下载成功，但 SHA256 校验未通过。"
            case .invalidResponse: return "服务器返回了无效的响应。"
            case .fileAlreadyExists: return "临时文件已存在，无法开始下载。"
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
    
    // 新增：临时文件 URL
    private var tempDestinationURL: URL!
    
    private var session: URLSession!
    
    // 下载状态追踪
    private var currentTask: URLSessionDataTask?
    private var fileHandle: FileHandle?
    private var currentDownloadedBytes: Int64 = 0
    private var totalExpectedBytes: Int64 = 0
    private var onProgress: (@Sendable (Double) -> Void)?
    private let queue = DispatchQueue(label: "com.downloader.queue", attributes: .concurrent) // 改为并发队列以提高读写效率
    private var continuation: CheckedContinuation<Void, Error>?
    
    // 取消令牌
    private var isCancelled = false
    
    // MARK: - Initialization
    /// 初始化下载器
    /// - Parameters:
    ///   - urls: 下载链接数组（应按优先级排序）
    ///   - destinationURL: 本地保存的目标文件路径
    ///   - expectedSHA256: 可选的 SHA256 校验码（Hex 字符串）
    public init(urls: [URL], destinationURL: URL, expectedSHA256: String? = nil) {
        self.urls = urls
        self.destinationURL = destinationURL
        self.expectedSHA256 = expectedSHA256
        super.init()
        
        // 初始化临时文件路径
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
        self.tempDestinationURL = tempDir.appendingPathComponent(destinationURL.lastPathComponent)
            .appendingPathExtension("\(ProcessInfo.processInfo.globallyUniqueString).tmp")
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15.0
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    
    // MARK: - Public Methods
    /// 开始执行下载流程
    /// - Parameter progress: 进度回调闭包
    public func startDownload(progress: @escaping @Sendable (Double) -> Void) async throws {
        self.onProgress = progress
        self.isCancelled = false
        
        // 1. 并发检测所有链接的可访问性
        let accessibleUrls = await filterAccessibleUrls(from: self.urls)
        guard !accessibleUrls.isEmpty else {
            throw DownloadError.noValidUrls
        }
        
        // 2. 依次尝试可用的链接进行断点续传下载
        var downloadSuccess = false
        for url in accessibleUrls {
            if isCancelled { break }
            
            var retryAttempt = 0
            while retryAttempt < maxRetryCount {
                if isCancelled { break }
                
                do {
                    try await performDownload(from: url)
                    downloadSuccess = true
                    break
                } catch {
                    retryAttempt += 1
                    cleanTemporaryState()
                    
                    if retryAttempt < maxRetryCount {
                        let delaySeconds = pow(2.0, Double(retryAttempt))
                        try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
                    }
                }
            }
            if downloadSuccess { break }
        }
        
        guard downloadSuccess else {
            throw DownloadError.allSourcesFailed
        }
        
        // 3. 文件完整性校验
        if let expectedHash = expectedSHA256 {
            let isValid = verifySHA256(for: tempDestinationURL, expected: expectedHash)
            if !isValid {
                try? fileManager.removeItem(at: tempDestinationURL)
                throw DownloadError.verificationFailed
            }
        }
        
        // 4. 原子性移动：只有校验通过才替换目标文件
        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.moveItem(at: tempDestinationURL, to: destinationURL)
        } catch {
            try? fileManager.removeItem(at: tempDestinationURL)
            throw error
        }
    }
    
    /// 显式取消当前下载任务
    public func cancel() {
        queue.async(flags: .barrier) { // 使用 barrier 确保线程安全
            self.isCancelled = true
            self.currentTask?.cancel()
            self.cleanTemporaryState()
            
            // 清理临时文件
            if let tempURL = self.tempDestinationURL,
               self.fileManager.fileExists(atPath: tempURL.path) {
                try? self.fileManager.removeItem(at: tempURL)
            }
            
            self.continuation?.resume(throwing: CancellationError())
            self.continuation = nil
        }
    }
    
    // MARK: - Private Helper Methods
    /// 核心下载逻辑（支持断点续传）
    private func performDownload(from url: URL) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            self.queue.async(flags: .barrier) {
                // 检查取消状态
                if self.isCancelled {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                
                self.continuation = continuation
                var request = URLRequest(url: url)
                
                // 检查临时文件是否存在以进行断点续传
                if self.fileManager.fileExists(atPath: self.tempDestinationURL.path) {
                    let attributes = try? self.fileManager.attributesOfItem(atPath: self.tempDestinationURL.path)
                    self.currentDownloadedBytes = attributes?[.size] as? Int64 ?? 0
                } else {
                    self.currentDownloadedBytes = 0
                }
                
                // 设置请求头
                if self.currentDownloadedBytes > 0 {
                    request.setValue("bytes=\(self.currentDownloadedBytes)-", forHTTPHeaderField: "Range")
                }
                
                // 打开文件句柄
                do {
                    if !self.fileManager.fileExists(atPath: self.tempDestinationURL.path) {
                        self.fileManager.createFile(atPath: self.tempDestinationURL.path, contents: nil, attributes: nil)
                    }
                    self.fileHandle = try FileHandle(forWritingTo: self.tempDestinationURL)
                    try self.fileHandle?.seek(toOffset: UInt64(self.currentDownloadedBytes))
                } catch {
                    continuation.resume(throwing: error)
                    return
                }
                
                let task = self.session.dataTask(with: request)
                self.currentTask = task
                task.resume()
            }
        }
    }
    
    /// 并发检测链接是否可用 (HEAD 请求)
    private func filterAccessibleUrls(from sourceUrls: [URL]) async -> [URL] {
        // 使用独立的 session 用于探测，避免阻塞主下载 session
        let probeSession = URLSession(configuration: URLSessionConfiguration.default)
        
        return await withTaskGroup(of: (URL, Bool).self) { group in
            for url in sourceUrls {
                group.addTask {
                    var request = URLRequest(url: url)
                    request.httpMethod = "HEAD"
                    request.timeoutInterval = 5.0
                    
                    do {
                        let (_, response) = try await probeSession.data(for: request)
                        if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                            return (url, true)
                        }
                    } catch {
                        // 可以选择打印日志，但在 2026 年，静默失败通常更优雅
                    }
                    return (url, false)
                }
            }
            
            var validUrls: [URL] = []
            for await (url, isAccessible) in group {
                if isAccessible {
                    validUrls.append(url)
                }
            }
            return sourceUrls.filter { validUrls.contains($0) }
        }
    }
    
    /// SHA256 流式校验
    private func verifySHA256(for fileURL: URL, expected: String) -> Bool {
        guard let fileHandle = try? FileHandle(forReadingFrom: fileURL) else { return false }
        defer {
            try? fileHandle.close()
        }
        
        var hasher = SHA256()
        let bufferSize = 64 * 1024
        
        while !self.isCancelled { // 增加取消检查
            guard let data = try? fileHandle.read(upToCount: bufferSize), !data.isEmpty else { break }
            hasher.update(data: data)
        }
        
        guard !self.isCancelled else { return false }
        
        let digest = hasher.finalize()
        let hashString = digest.map { String(format: "%02hhx", $0) }.joined()
        return hashString.lowercased() == expected.lowercased()
    }
    
    private func cleanTemporaryState() {
        queue.async(flags: .barrier) {
            try? self.fileHandle?.close()
            self.fileHandle = nil
            self.currentTask = nil
        }
    }
}

// MARK: - URLSessionDataDelegate
extension MultiSourceDownloader: URLSessionDataDelegate {
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        queue.async(flags: .barrier) {
            guard let httpResponse = response as? HTTPURLResponse else {
                completionHandler(.cancel)
                return
            }
            
            let statusCode = httpResponse.statusCode
            if statusCode == 206 {
                // 处理断点续传
                if let contentRange = httpResponse.value(forHTTPHeaderField: "Content-Range"),
                   let totalStr = contentRange.components(separatedBy: "/").last {
                    self.totalExpectedBytes = Int64(totalStr) ?? httpResponse.expectedContentLength
                } else {
                    self.totalExpectedBytes = httpResponse.expectedContentLength
                }
                completionHandler(.allow)
            } else if statusCode == 200 {
                // 服务器不支持断点续传，重置
                self.currentDownloadedBytes = 0
                self.totalExpectedBytes = httpResponse.expectedContentLength
                // 确保文件句柄重置（在 performDownload 中已处理，这里双重保险）
                try? self.fileHandle?.seek(toOffset: 0)
                try? self.fileHandle?.truncate(atOffset: 0)
                completionHandler(.allow)
            } else {
                completionHandler(.cancel)
            }
        }
    }
    
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        queue.async(flags: .barrier) {
            guard let fileHandle = self.fileHandle, !self.isCancelled else { return }
            
            do {
                try fileHandle.write(contentsOf: data)
                let dataCount = Int64(data.count)
                self.currentDownloadedBytes += dataCount
                
                // 进度回调（增加节流逻辑可选，这里保持简单）
                if self.totalExpectedBytes > 0 {
                    let progress = Double(self.currentDownloadedBytes) / Double(self.totalExpectedBytes)
                    // 确保在主线程回调
                    DispatchQueue.main.async {
                        self.onProgress?(max(0, min(1, progress))) // 限制在 0-1 范围内
                    }
                }
            } catch {
                self.currentTask?.cancel()
                self.continuation?.resume(throwing: error)
                self.continuation = nil
            }
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        queue.async(flags: .barrier) {
            defer { self.cleanTemporaryState() }
            
            if let error = error {
                if (error as? URLError)?.code == .cancelled || self.isCancelled {
                    self.continuation?.resume(throwing: CancellationError())
                } else {
                    self.continuation?.resume(throwing: error)
                }
            } else {
                // 下载成功完成
                // 注意：这里只是下载完成了，不代表校验通过。校验在 startDownload 中进行。
                self.continuation?.resume()
            }
            self.continuation = nil
        }
    }
}
