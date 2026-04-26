//
//  FileTools.swift
//  TTSmate
//
//  Created by yangxuehui on 2026/1/2.
//

//
//  FileTools.swift
//
//  Created by ChatGPT for macOS App
//

import Foundation
import AppKit

/// 文件系统工具类（macOS / Sandbox 适配）
///
/// 设计目标：
/// - 所有路径统一用 URL
/// - 默认工作在 App Documents
/// - 安全、可读、可扩展
///
public final class FileTools {
    
    // MARK: - FileManager
    
    nonisolated(unsafe) public static let fm = FileManager.default
    // MARK: - Base Directories
    
    /// App Documents 目录（Sandbox 下）
    public static var documentsDirectory: URL {
        fm.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    /// App Caches 目录
    public static var cachesDirectory: URL {
        fm.urls(for: .cachesDirectory, in: .userDomainMask).first!
    }

    /// App Application Support 目录
    public static var applicationSupportDirectory: URL {
        fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    }
    
    /// App Temporary 目录
    public static var temporaryDirectory: URL {
        fm.temporaryDirectory
    }
    
    // MARK: - Path Builder
    
    /// 在 Documents 下拼接路径
    public static func documentsPath(_ components: String...) -> URL {
        components.reduce(documentsDirectory) {
            $0.appendingPathComponent($1)
        }
    }
    
    /// 在 Caches 下拼接路径
    public static func cachesPath(_ components: String...) -> URL {
        components.reduce(cachesDirectory) {
            $0.appendingPathComponent($1)
        }
    }

    /// 在 Application Support 下拼接路径
    public static func applicationSupportPath(_ components: String...) -> URL {
        components.reduce(applicationSupportDirectory) {
            $0.appendingPathComponent($1)
        }
    }
    
    // MARK: - Existence
    
    /// 文件或目录是否存在
    public static func exists(_ url: URL) -> Bool {
        fm.fileExists(atPath: url.path)
    }
    
    /// 是否为目录
    public static func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        fm.fileExists(atPath: url.path, isDirectory: &isDir)
        return isDir.boolValue
    }
    
    // MARK: - Permissions
    
    /// 是否可写
    public static func isWritable(_ url: URL) -> Bool {
        fm.isWritableFile(atPath: url.path)
    }
    
    /// 确保目录存在（不存在就创建）
    @discardableResult
    public static func ensureDirectory(_ url: URL) throws -> URL {
        guard !exists(url) else { return url }
        try fm.createDirectory(
            at: url,
            withIntermediateDirectories: true,
            attributes: nil
        )
        return url
    }
    
    // MARK: - File Operations
    
    /// 创建空文件（可用于占位）
    public static func createFile(
        at url: URL,
        overwrite: Bool = false
    ) throws {
        if exists(url) {
            if overwrite {
                try fm.removeItem(at: url)
            } else {
                return
            }
        }
        fm.createFile(atPath: url.path, contents: nil)
    }
    
    /// 删除文件或目录
    public static func remove(_ url: URL) throws {
        guard exists(url) else { return }
        try fm.removeItem(at: url)
    }
    
    /// 拷贝
    public static func copy(from src: URL, to dst: URL, overwrite: Bool = false) throws {
        if exists(dst) {
            if overwrite {
                try remove(dst)
            } else {
                return
            }
        }
        try ensureDirectory(dst.deletingLastPathComponent())
        try fm.copyItem(at: src, to: dst)
    }
    
    /// 移动
    public static func move(from src: URL, to dst: URL, overwrite: Bool = false) throws {
        if exists(dst) {
            if overwrite {
                try remove(dst)
            } else {
                return
            }
        }
        try ensureDirectory(dst.deletingLastPathComponent())
        try fm.moveItem(at: src, to: dst)
    }
    
    // MARK: - File Info
    
    /// 文件大小（字节）
    public static func fileSize(_ url: URL) -> Int64 {
        guard
            let attr = try? fm.attributesOfItem(atPath: url.path),
            let size = attr[.size] as? NSNumber
        else {
            return 0
        }
        return size.int64Value
    }
    
    /// 友好的文件大小字符串
    public static func readableFileSize(_ url: URL) -> String {
        let size = fileSize(url)
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    // MARK: - Cleanup
    
    /// 清空目录（不删除目录本身）
    public static func clearDirectory(_ url: URL) throws {
        guard exists(url) else { return }
        let items = try fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil
        )
        for item in items {
            try fm.removeItem(at: item)
        }
    }
    
    //MARK: 在 Finder 中显示文件或打开目录
    // 更完善的调用方式，如果是文件，就是打开 finder 并选中文件。如果是目录，就直接打开。
    //如果 flag 为 true，则指定用activateFileViewerSelecting
    @MainActor
    public static func openInFinder(_ url: URL,flag:Bool = false) {
        // 1️⃣ 基础校验
        guard url.isFileURL else { return }
        
        let path = url.path
        guard FileManager.default.fileExists(atPath: path) else { return }
        
        // 2️⃣ 判断是否是目录
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        
        if isDirectory.boolValue {
            if flag {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }else{
                // 📂 目录 → 直接打开
                NSWorkspace.shared.open(url)
            }
        } else {
            // 📄 文件 → 打开 Finder 并选中
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }
    // MARK: - Audio Playback (System Default)
    
    /// 使用系统默认应用播放音频文件
    /// - Parameter url: 音频文件 URL
    public static func playAudioWithSystem(_ url: URL) {
        guard exists(url) else {
            print("❌ 音频文件不存在：\(url.path)")
            return
        }
        
        NSWorkspace.shared.open(url)
    }
    //判断文件是否存在
    public static func fileExists(url:URL) -> Bool {
        let ret = FileManager.default.fileExists(atPath: url.path)
        return ret
    }
    public static func fileExists(path:String) -> Bool {
        let ret = FileManager.default.fileExists(atPath: path)
        return ret
    }
    
    //    let fileURL = try FileTools.shared.audioFileURL(
    //        projectID: project!.id,
    //        fileName: "\(chapter!.name).mp3"
    //    )
    // MARK: - Audio File Path
    
    /// 获取音频文件 URL（Documents / projectName / fileName）
    ///
    /// - Parameters:
    ///   - projectId: 项目名称（作为子目录名）
    ///   - fileName: 文件名（如 "chapter1.mp3"）
    /// - Returns: 文件 URL
    /// - Throws: 目录创建失败时抛出异常
    public static func audioFileURL(
        projectId: String,
        fileName: String
    ) throws -> URL {
        
        guard !projectId.isEmpty else {
            throw NSError(
                domain: "FileTools",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "projectId 不能为空"]
            )
        }
        
        guard !fileName.isEmpty else {
            throw NSError(
                domain: "FileTools",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "fileName 不能为空"]
            )
        }
        
        // Documents / projectName
        let projectDir = documentsDirectory
            .appendingPathComponent(projectId, isDirectory: true)
        
        // 确保目录存在
        try ensureDirectory(projectDir)
        
        // Documents / projectName / fileName
        return projectDir.appendingPathComponent(fileName)
    }
    
    public static func getFileName(url:URL) -> String {
        return url.deletingPathExtension().lastPathComponent
    }
    
    public static func isImage(urls: [URL]) -> Bool {
        guard urls.isEmpty == false else { return false }
        
        let imageExts: Set<String> = [
            "png", "jpg", "jpeg", "bmp", "gif", "tiff"
        ]
        
        return urls.allSatisfy { url in
            imageExts.contains(url.pathExtension.lowercased())
        }
    }
    public static func copyTextsToPasteboard(_ texts: [String]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(texts.joined(separator: "\n"), forType: .string)
        NSSound.beep()
    }
}
