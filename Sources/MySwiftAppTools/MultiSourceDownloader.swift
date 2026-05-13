import Foundation
import CryptoKit

/// ⚠️ 必须在主项目或包的 Build Settings 中将 Swift Language Version 设为 5.5 或以上。
public final class MultiSourceDownloader: NSObject, @unchecked Sendable {

    // MARK: - Types

    /// 哈希算法类型
    public enum HashAlgorithm: String, Codable, Sendable {
        case sha256 = "SHA256"
        case sha1 = "SHA1"
        case md5 = "MD5"

        public var displayName: String { rawValue }
    }

    /// 下载进度信息
    public struct Progress: Sendable {
        /// 当前进度 (0.0 - 1.0)
        public let fractionCompleted: Double
        /// 已下载字节数
        public let downloadedBytes: Int64
        /// 文件总字节数
        public let totalBytes: Int64
        /// 当前下载速度 (bytes/second)
        public let speed: Double
        /// 预估剩余时间 (秒)
        public let remainingSeconds: Double?

        public init(
            fractionCompleted: Double,
            downloadedBytes: Int64,
            totalBytes: Int64,
            speed: Double,
            remainingSeconds: Double?
        ) {
            self.fractionCompleted = fractionCompleted
            self.downloadedBytes = downloadedBytes
            self.totalBytes = totalBytes
            self.speed = speed
            self.remainingSeconds = remainingSeconds
        }

        /// 格式化速度字符串 (e.g., "1.5 MB/s")
        public var formattedSpeed: String {
            if speed >= 1_000_000 {
                return String(format: "%.1f MB/s", speed / 1_000_000)
            } else if speed >= 1_000 {
                return String(format: "%.1f KB/s", speed / 1_000)
            } else {
                return String(format: "%.0f B/s", speed)
            }
        }

        /// 格式化剩余时间字符串 (e.g., "1:30")
        public var formattedRemainingTime: String {
            guard let remaining = remainingSeconds, remaining.isFinite && remaining > 0 else {
                return "--:--"
            }
            let totalSeconds = Int(remaining)
            if totalSeconds >= 3600 {
                let hours = totalSeconds / 3600
                let minutes = (totalSeconds % 3600) / 60
                return String(format: "%d:%02d:%02d", hours, minutes, totalSeconds % 60)
            } else {
                let minutes = totalSeconds / 60
                let seconds = totalSeconds % 60
                return String(format: "%d:%02d", minutes, seconds)
            }
        }
    }

    public enum DownloadError: Error, LocalizedError {
        case noValidUrls
        case allSourcesFailed
        case verificationFailed(algorithm: HashAlgorithm, url: URL, expected: String, actual: String)
        case invalidResponse
        case fileAlreadyExists

        public var errorDescription: String? {
            switch self {
            case .noValidUrls:
                return packageL(MySwiftAppToolsL10n.downloaderNoValidUrls)
            case .allSourcesFailed:
                return packageL(MySwiftAppToolsL10n.downloaderAllSourcesFailed)
            case .verificationFailed(let algorithm, let url, let expected, let actual):
                return packageL(
                    MySwiftAppToolsL10n.downloaderVerificationFailed,
                    url.lastPathComponent,
                    algorithm.displayName,
                    expected,
                    actual
                )
            case .invalidResponse:
                return packageL(MySwiftAppToolsL10n.downloaderInvalidResponse)
            case .fileAlreadyExists:
                return packageL(MySwiftAppToolsL10n.downloaderFileAlreadyExists)
            }
        }
    }

    /// 下载行为配置。
    ///
    /// 调用示例：
    /// ```swift
    /// let downloader = MultiSourceDownloader(
    ///     urls: [chinaMirrorURL, githubURL],
    ///     destinationURL: localModelURL,
    ///     hashAlgorithm: .sha256,
    ///     expectedHash: sha256,
    ///     configuration: .init(
    ///         maxRetryCount: 3,
    ///         requestTimeout: 30,
    ///         probeTimeout: 6,
    ///         allowsCrossSourceResume: false
    ///     )
    /// )
    /// ```
    public struct Configuration: Sendable {
        /// 单个源最多重试次数。
        public var maxRetryCount: Int
        /// 正式下载请求超时时间。
        public var requestTimeout: TimeInterval
        /// 可用性探测超时时间。
        public var probeTimeout: TimeInterval
        /// 是否允许不同源之间复用同一个临时文件做断点续传。
        ///
        /// 默认关闭。不同镜像虽然文件名一样，但内容版本可能不一致；跨源续传可能拼出损坏文件。
        /// 如果你有强 hash 校验，并且确定多个源完全等价，可以打开。
        public var allowsCrossSourceResume: Bool

        public init(
            maxRetryCount: Int = 3,
            requestTimeout: TimeInterval = 15,
            probeTimeout: TimeInterval = 5,
            allowsCrossSourceResume: Bool = false
        ) {
            self.maxRetryCount = max(1, maxRetryCount)
            self.requestTimeout = requestTimeout
            self.probeTimeout = probeTimeout
            self.allowsCrossSourceResume = allowsCrossSourceResume
        }

        public static let `default` = Configuration()
    }

    private struct SourceProbe: Sendable {
        let url: URL
        let responseTime: TimeInterval
        let supportsRange: Bool
        let contentLength: Int64
    }

    // MARK: - Properties
    public let urls: [URL]
    public let destinationURL: URL
    public let hashAlgorithm: HashAlgorithm?
    public let expectedHash: String?
    public let configuration: Configuration

    private let fileManager = FileManager.default

    // 临时文件 URL
    private var tempDestinationURL: URL!

    private var session: URLSession!

    // 下载状态追踪
    private var currentTask: URLSessionDataTask?
    private var currentSourceURL: URL?
    private var fileHandle: FileHandle?
    private var currentDownloadedBytes: Int64 = 0
    private var totalExpectedBytes: Int64 = 0
    private var onProgress: (@Sendable (Progress) -> Void)?

    // 速度计算
    private var lastBytesSnapshot: Int64 = 0
    private var lastTimeSnapshot: Date = Date()
    private var currentSpeed: Double = 0

    private let queue = DispatchQueue(label: "com.downloader.queue", attributes: .concurrent)
    private var continuation: CheckedContinuation<Void, Error>?

    // 取消令牌
    private var isCancelled = false

    // MARK: - Initialization

    /// 初始化下载器
    /// - Parameters:
    ///   - urls: 下载链接数组（应按优先级排序）
    ///   - destinationURL: 本地保存的目标文件路径
    ///   - hashAlgorithm: 哈希算法类型（SHA256、SHA1、MD5）
    ///   - expectedHash: 可选的哈希校验码（Hex 字符串）
    public init(
        urls: [URL],
        destinationURL: URL,
        hashAlgorithm: HashAlgorithm? = .sha256,
        expectedHash: String? = nil,
        configuration: Configuration = .default
    ) {
        self.urls = urls
        self.destinationURL = destinationURL
        self.hashAlgorithm = hashAlgorithm
        self.expectedHash = expectedHash
        self.configuration = configuration
        super.init()

        // 初始化临时文件路径
        let tempDir = destinationURL.deletingLastPathComponent()
        self.tempDestinationURL = tempDir
            .appendingPathComponent(destinationURL.lastPathComponent)
            .appendingPathExtension("\(ProcessInfo.processInfo.globallyUniqueString).tmp")

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = configuration.requestTimeout
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    /// 简化的初始化方法（仅 SHA256）
    public init(
        urls: [URL],
        destinationURL: URL,
        expectedSHA256: String?,
        configuration: Configuration = .default
    ) {
        self.urls = urls
        self.destinationURL = destinationURL
        self.hashAlgorithm = expectedSHA256 != nil ? .sha256 : nil
        self.expectedHash = expectedSHA256
        self.configuration = configuration
        super.init()

        let tempDir = destinationURL.deletingLastPathComponent()
        self.tempDestinationURL = tempDir
            .appendingPathComponent(destinationURL.lastPathComponent)
            .appendingPathExtension("\(ProcessInfo.processInfo.globallyUniqueString).tmp")

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = configuration.requestTimeout
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    // MARK: - Public Methods

    /// 开始执行下载流程
    /// - Parameter progress: 进度回调闭包
    public func startDownload(progress: @escaping @Sendable (Progress) -> Void) async throws {
        self.onProgress = progress
        self.isCancelled = false
        self.lastBytesSnapshot = 0
        self.lastTimeSnapshot = Date()
        self.currentSpeed = 0

        try fileManager.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        // 1. 并发检测所有链接的可访问性，并按稳定度排序
        let accessibleSources = await probeAccessibleSources(from: self.urls)
        guard !accessibleSources.isEmpty else {
            throw DownloadError.noValidUrls
        }

        // 2. 依次尝试可用的链接进行断点续传下载
        var downloadSuccess = false
        var isFirstSource = true
        for source in accessibleSources {
            if isCancelled { break }

            if !isFirstSource && !configuration.allowsCrossSourceResume {
                removeTemporaryFile()
                currentDownloadedBytes = 0
            }
            isFirstSource = false

            var retryAttempt = 0
            while retryAttempt < configuration.maxRetryCount {
                if isCancelled { break }

                do {
                    try await performDownload(from: source.url)
                    downloadSuccess = true
                    break
                } catch {
                    retryAttempt += 1
                    cleanTemporaryState()

                    if retryAttempt < configuration.maxRetryCount {
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
        if let algorithm = hashAlgorithm, let expected = expectedHash {
            let (isValid, actualHash) = verifyHash(for: tempDestinationURL, algorithm: algorithm, expected: expected)
            if !isValid {
                try? fileManager.removeItem(at: tempDestinationURL)
                throw DownloadError.verificationFailed(
                    algorithm: algorithm,
                    url: currentSourceURL ?? urls.first!,
                    expected: expected,
                    actual: actualHash
                )
            }
        }

        // 4. 原子性替换：只有校验通过才替换目标文件
        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                _ = try fileManager.replaceItemAt(
                    destinationURL,
                    withItemAt: tempDestinationURL,
                    backupItemName: nil,
                    options: []
                )
            } else {
                try fileManager.moveItem(at: tempDestinationURL, to: destinationURL)
            }
        } catch {
            try? fileManager.removeItem(at: tempDestinationURL)
            throw error
        }
    }

    /// 显式取消当前下载任务
    public func cancel() {
        queue.async(flags: .barrier) {
            self.isCancelled = true
            self.currentTask?.cancel()
            self.cleanTemporaryState()

            // 清理临时文件
            self.removeTemporaryFile()

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
                self.currentSourceURL = url
                var request = URLRequest(url: url)

                // 检查临时文件是否存在以进行断点续传
                if self.fileManager.fileExists(atPath: self.tempDestinationURL.path) {
                    let attributes = try? self.fileManager.attributesOfItem(atPath: self.tempDestinationURL.path)
                    self.currentDownloadedBytes = attributes?[.size] as? Int64 ?? 0
                } else {
                    self.currentDownloadedBytes = 0
                }

                // 重置速度统计
                self.lastBytesSnapshot = self.currentDownloadedBytes
                self.lastTimeSnapshot = Date()
                self.currentSpeed = 0

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

    /// 并发检测链接是否可用。
    ///
    /// 优先使用 HEAD；如果服务端不支持 HEAD，再退回到 `GET Range: bytes=0-0`。
    /// 返回结果会按“支持 Range、响应快、原始顺序靠前”排序。
    private func probeAccessibleSources(from sourceUrls: [URL]) async -> [SourceProbe] {
        let probeSession = URLSession(configuration: URLSessionConfiguration.default)

        return await withTaskGroup(of: (Int, SourceProbe?).self) { group in
            for (index, url) in sourceUrls.enumerated() {
                group.addTask {
                    let startedAt = Date()
                    var request = URLRequest(url: url)
                    request.httpMethod = "HEAD"
                    request.timeoutInterval = self.configuration.probeTimeout

                    do {
                        let (_, response) = try await probeSession.data(for: request)
                        if let probe = Self.makeProbe(
                            url: url,
                            response: response,
                            responseTime: Date().timeIntervalSince(startedAt)
                        ) {
                            return (index, probe)
                        }
                    } catch {
                        // 继续尝试 Range GET。
                    }

                    var fallbackRequest = URLRequest(url: url)
                    fallbackRequest.httpMethod = "GET"
                    fallbackRequest.setValue("bytes=0-0", forHTTPHeaderField: "Range")
                    fallbackRequest.timeoutInterval = self.configuration.probeTimeout

                    do {
                        let (_, response) = try await probeSession.data(for: fallbackRequest)
                        if let probe = Self.makeProbe(
                            url: url,
                            response: response,
                            responseTime: Date().timeIntervalSince(startedAt)
                        ) {
                            return (index, probe)
                        }
                    } catch {
                        // 静默失败，让下一个源接管。
                    }

                    return (index, nil)
                }
            }

            var probes: [(Int, SourceProbe)] = []
            for await (index, probe) in group {
                if let probe {
                    probes.append((index, probe))
                }
            }

            return probes.sorted { lhs, rhs in
                if lhs.1.supportsRange != rhs.1.supportsRange {
                    return lhs.1.supportsRange && !rhs.1.supportsRange
                }

                let responseDelta = abs(lhs.1.responseTime - rhs.1.responseTime)
                if responseDelta > 0.05 {
                    return lhs.1.responseTime < rhs.1.responseTime
                }

                return lhs.0 < rhs.0
            }.map(\.1)
        }
    }

    private static func makeProbe(url: URL, response: URLResponse, responseTime: TimeInterval) -> SourceProbe? {
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) || httpResponse.statusCode == 206
        else {
            return nil
        }

        let acceptRanges = httpResponse.value(forHTTPHeaderField: "Accept-Ranges")?.lowercased()
        let supportsRange = httpResponse.statusCode == 206 || acceptRanges == "bytes"
        let contentLength = Self.contentLength(from: httpResponse)

        return SourceProbe(
            url: url,
            responseTime: responseTime,
            supportsRange: supportsRange,
            contentLength: contentLength
        )
    }

    private static func contentLength(from response: HTTPURLResponse) -> Int64 {
        if let contentRange = response.value(forHTTPHeaderField: "Content-Range"),
           let totalString = contentRange.components(separatedBy: "/").last,
           let total = Int64(totalString) {
            return total
        }

        return response.expectedContentLength
    }

    /// 哈希校验
    private func verifyHash(for fileURL: URL, algorithm: HashAlgorithm, expected: String) -> (Bool, String) {
        guard let fileHandle = try? FileHandle(forReadingFrom: fileURL) else { return (false, "") }
        defer {
            try? fileHandle.close()
        }

        let bufferSize = 64 * 1024
        let hashString: String

        switch algorithm {
        case .sha256:
            var hasher = SHA256()
            while !self.isCancelled {
                guard let data = try? fileHandle.read(upToCount: bufferSize), !data.isEmpty else { break }
                hasher.update(data: data)
            }
            guard !self.isCancelled else { return (false, "") }
            let digest = hasher.finalize()
            hashString = digest.map { String(format: "%02hhx", $0) }.joined()

        case .sha1:
            var hasher = Insecure.SHA1()
            while !self.isCancelled {
                guard let data = try? fileHandle.read(upToCount: bufferSize), !data.isEmpty else { break }
                hasher.update(data: data)
            }
            guard !self.isCancelled else { return (false, "") }
            let digest = hasher.finalize()
            hashString = digest.map { String(format: "%02hhx", $0) }.joined()

        case .md5:
            var hasher = Insecure.MD5()
            while !self.isCancelled {
                guard let data = try? fileHandle.read(upToCount: bufferSize), !data.isEmpty else { break }
                hasher.update(data: data)
            }
            guard !self.isCancelled else { return (false, "") }
            let digest = hasher.finalize()
            hashString = digest.map { String(format: "%02hhx", $0) }.joined()
        }

        let isValid = hashString.lowercased() == expected.lowercased()
        return (isValid, hashString)
    }

    /// 计算当前下载速度并发送进度回调
    private func reportProgress() {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastTimeSnapshot)

        if elapsed >= 0.5 { // 每 0.5 秒更新一次速度
            let bytesDiff = currentDownloadedBytes - lastBytesSnapshot
            currentSpeed = Double(bytesDiff) / elapsed
            lastBytesSnapshot = currentDownloadedBytes
            lastTimeSnapshot = now
        }

        let fraction = totalExpectedBytes > 0 ? Double(currentDownloadedBytes) / Double(totalExpectedBytes) : 0

        // 计算剩余时间
        var remainingSeconds: Double? = nil
        if currentSpeed > 0 && totalExpectedBytes > currentDownloadedBytes {
            let remainingBytes = Double(totalExpectedBytes - currentDownloadedBytes)
            remainingSeconds = remainingBytes / currentSpeed
        }

        let progress = Progress(
            fractionCompleted: max(0, min(1, fraction)),
            downloadedBytes: currentDownloadedBytes,
            totalBytes: totalExpectedBytes,
            speed: currentSpeed,
            remainingSeconds: remainingSeconds
        )

        DispatchQueue.main.async {
            self.onProgress?(progress)
        }
    }

    private func cleanTemporaryState() {
        queue.async(flags: .barrier) {
            self.currentTask = nil
            self.currentSourceURL = nil
        }
        try? self.fileHandle?.close()
        self.fileHandle = nil
    }

    private func removeTemporaryFile() {
        if let tempURL = tempDestinationURL,
           fileManager.fileExists(atPath: tempURL.path) {
            try? fileManager.removeItem(at: tempURL)
        }
    }
}

// MARK: - URLSessionDataDelegate
extension MultiSourceDownloader: URLSessionDataDelegate {

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        let disposition: URLSession.ResponseDisposition = queue.sync(flags: .barrier) {
            guard let httpResponse = response as? HTTPURLResponse else {
                return .cancel
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
                return .allow
            } else if statusCode == 200 {
                // 服务器不支持断点续传，重置
                self.currentDownloadedBytes = 0
                self.totalExpectedBytes = httpResponse.expectedContentLength
                try? self.fileHandle?.seek(toOffset: 0)
                try? self.fileHandle?.truncate(atOffset: 0)
                return .allow
            } else {
                return .cancel
            }
        }

        completionHandler(disposition)
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        queue.async(flags: .barrier) {
            guard let fileHandle = self.fileHandle, !self.isCancelled else { return }

            do {
                try fileHandle.write(contentsOf: data)
                self.currentDownloadedBytes += Int64(data.count)
                self.reportProgress()
            } catch {
                self.currentTask?.cancel()
                self.continuation?.resume(throwing: error)
                self.continuation = nil
            }
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        queue.async(flags: .barrier) {
            try? self.fileHandle?.close()
            self.fileHandle = nil
            self.currentTask = nil

            if let error = error {
                if (error as? URLError)?.code == .cancelled || self.isCancelled {
                    self.continuation?.resume(throwing: CancellationError())
                } else {
                    self.continuation?.resume(throwing: error)
                }
            } else {
                self.continuation?.resume()
            }
            self.continuation = nil
        }
    }
}
