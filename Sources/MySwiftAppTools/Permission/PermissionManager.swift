import AppKit

public enum PermissionPurpose: Sendable {
    case read          // 只需要访问（Finder / 打开终端）
    case write         // 需要写（生成 / 修改 / 删除）
}

//返回给调用方，把匹配到的 bookmark 的 url 返回，以供调用方 stop 权限
public struct PermissionUrlGroup: Sendable {
    //这个 url 来源是调用方发出的 url
    public var url:URL?
    /*
     这个值是肯定有的，即使一开始没有，也会弹出窗口让用户授权，然后再返回
     调用方拿到这个 matchUrl，用于 stopAccessingSecurityScopedResource 和 stop权限
     */
    public var matchUrl:URL
}

@MainActor
public final class PermissionManager {
    
    public static let shared = PermissionManager()
    private init() {}
    
    private var isRequesting = false
    
    // MARK: - 已指定url统一入口
    @MainActor
    public func ensureAccess(
        for url: URL,
        purpose: PermissionPurpose
    ) async -> PermissionUrlGroup? {
        //根据 url 找到目录，所有权限操作都是目录级的
        let targetDir = normalizeToDirectory(url)
        
        // 1️⃣ 尝试从 bookmark 恢复（按精确度排序）
        if let pug = restoreBestMatch(from: targetDir, purpose: purpose) {
            print("✅ 使用 bookmark: \(pug.matchUrl.path)")
            return pug
        }
        
        // 2️⃣ 无可用 bookmark → 请求授权
        return await requestDirectoryAccess(targetDir, purpose: purpose)
    }
    
    //拼接目录，供外部调用方基于matchUrl拼接出具体的访问 url
    public func buildChildURL(
        matchUrl: URL,
        targetUrl: URL
    ) -> URL? {
        
        let base = matchUrl.normalized
        let target = targetUrl.normalized
        
        // 1️⃣ 必须在权限范围内
        guard target.path == base.path ||
                target.path.hasPrefix(base.path + "/") else {
            return nil
        }
        
        // 2️⃣ 如果正好是根目录，直接返回
        if target.path == base.path {
            return base
        }
        
        // 3️⃣ 计算相对路径（安全）
        let relativePath = String(
            target.path.dropFirst(base.path.count + 1)
        )
        
        return base.appendingPathComponent(relativePath)
    }

    
    //找到最匹配的目录权限，拼好 url，返回
    public func restoreBestMatch(
        from target: URL,
        purpose: PermissionPurpose
    ) -> PermissionUrlGroup? {
        
        let list = manager(for: purpose).load()
        
        let normalizedTarget = target.standardizedFileURL
        //先把所有 target 目录的父级目录都取出来
        let candidates: [(item: MyDirectory, baseURL: URL)] = list.compactMap { item in
            let itemURL = item.url.standardizedFileURL
            guard normalizedTarget.isIn(in: itemURL) else { return nil }
            
            let (baseURL, valid) = item.getSecurityScopedURL()
            guard valid, let baseURL else { return nil }
            
            return (item, baseURL.standardizedFileURL)
        }
        
        // 路径越长越精确
        let sorted = candidates.sorted {
            $0.item.url.path.count > $1.item.url.path.count
        }
        
        for candidate in sorted {
            
            let itemURL = candidate.item.url.normalized
            let baseURL = candidate.baseURL
            
            // 🔑 关键：用 bookmark URL 拼出真实目标
            let resolvedURL: URL
            guard baseURL.startAccessingSecurityScopedResource() else { continue }
            //这里不 stop，外面 stop
            defer { baseURL.stopAccessingSecurityScopedResource() }
            //如果正好路径相等
            if itemURL == normalizedTarget {
                resolvedURL = baseURL
            } else {
                //如果是子目录，就拼出来
                resolvedURL = self.buildChildURL(matchUrl: baseURL, targetUrl: normalizedTarget)!
//                let relativePath = normalizedTarget.path
//                    .dropFirst(itemURL.path.count)
//                    .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
//                resolvedURL = baseURL.appendingPathComponent(relativePath)
            }
            switch purpose {
            case .write:
                if isWritable(resolvedURL) {
                    print("restoreBestMatch输出可用写 bookmark 目录： \(resolvedURL.path)")
                    return PermissionUrlGroup(url: target,matchUrl: baseURL)
                }
            case .read:
                print("restoreBestMatch输出可用读 bookmark 目录： \(resolvedURL.path)")
                return PermissionUrlGroup(url: target,matchUrl: baseURL)
            }
        }
        
        return nil
    }
    
    
    
    // MARK: 未指定目标url入口
    public func ensureTargetDirectoryAccess(
        suggested: URL? = nil,
        purpose: PermissionPurpose = .write
    ) async -> PermissionUrlGroup? {
        if isRequesting { return nil }
        isRequesting = true
        defer { isRequesting = false }
        
        return await withCheckedContinuation { (continuation: CheckedContinuation<PermissionUrlGroup?, Never>) in
            
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.allowsMultipleSelection = false
            panel.directoryURL = suggested
            panel.title = MySwiftAppToolsL10n.authWriteTitle.toPackageNSLocalizedString
            panel.message = MySwiftAppToolsL10n.authWriteMsg.toPackageNSLocalizedString
            NSApp.activate(ignoringOtherApps: true)
            panel.begin { resp in
                guard resp == .OK, let url = panel.url else {
                    continuation.resume(returning: nil)
                    return
                }
                
                do {
                    let bookmark = try url.bookmarkData(
                        options: .withSecurityScope,
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                    //取出目录名
                    let name = url.normalized.deletingPathExtension().lastPathComponent
                    let entry = MyDirectory(
                        url: url,
                        bookmarkData: bookmark,
                        label: name, type: .history
                    )
                    // 覆盖旧记录
                    DirectoryManager.removeInType(url, type: .history)
                    DirectoryManager.appendAndSave(entry)
                    
                    //重新匹配
                    let pug = self.restoreBestMatch(from: url, purpose: purpose)
                    
                    continuation.resume(returning: pug)
                    
                } catch {
                    NSLog("❌ Target bookmark 创建失败: \(error)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    //根据一个 url 返回目录
    public func normalizeToDirectory(_ url: URL) -> URL {
        if url.hasDirectoryPath {
            return url.standardizedFileURL
        } else {
            return url.deletingLastPathComponent().standardizedFileURL
        }
    }
    
    //    func restoreFromBookmark(
    //        _ target: URL,
    //        purpose: PermissionPurpose
    //    ) -> URL? {
    //
    //        let list = manager(for: purpose).load()
    //
    //        for item in list {
    //
    //            guard target.isIn(in: item.url) else { continue }
    //
    //            let (baseURL, valid) = item.getSecurityScopedURL()
    //            guard valid, let baseURL else { continue }
    //
    //            switch purpose {
    //
    //            case .write:
    //                // 🔐 只有写操作才真正访问
    //                guard baseURL.startAccessingSecurityScopedResource() else { continue }
    //                defer { baseURL.stopAccessingSecurityScopedResource() }
    //
    //                if isWritable(baseURL) {
    //                    return baseURL
    //                }
    //
    //            case .read, .terminal:
    //                // ✅ 仅返回可用 URL，不触碰文件系统
    //                return baseURL
    //            }
    //        }
    //
    //        return nil
    //    }
    
    //请求目录访问赋权
    public func requestDirectoryAccess(
        _ suggested: URL,
        purpose: PermissionPurpose
    ) async -> PermissionUrlGroup? {
        
        if isRequesting { return nil }
        isRequesting = true
        defer { isRequesting = false }
        
        return await withCheckedContinuation { (continuation: CheckedContinuation<PermissionUrlGroup?, Never>) in
            
            let panel = NSOpenPanel()
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.allowsMultipleSelection = false
            panel.directoryURL = suggested
            panel.title = MySwiftAppToolsL10n.authWriteTitle.toPackageNSLocalizedString
            panel.message = MySwiftAppToolsL10n.authWriteMsg.toPackageNSLocalizedString
            NSApp.activate(ignoringOtherApps: true)
            panel.begin { resp in
                guard resp == .OK, let url = panel.url else {
                    continuation.resume(returning: nil)
                    return
                }
                
                do {
                    let bookmark = try url.bookmarkData(
                        options: .withSecurityScope,
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                    //取出目录名
                    let name = url.normalized.deletingPathExtension().lastPathComponent
                    let entry = MyDirectory(
                        url: url,
                        bookmarkData: bookmark,
                        label: name,
                        type: .history
                    )
                    // 覆盖旧记录
                    DirectoryManager.remove(url)
                    DirectoryManager.appendAndSave(entry)
                    
                    //重新匹配
                    let pug = self.restoreBestMatch(from: url, purpose: purpose)
                    
                    continuation.resume(returning: pug)
                    
                } catch {
                    NSLog("❌ Target bookmark 创建失败: \(error)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    public func isWritable(_ url: URL) -> Bool {
        let test = url.appendingPathComponent(".perm_test_\(UUID())")
        do {
            try "test".write(to: test, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(at: test)
            return true
        } catch {
            return false
        }
    }
    
    
    func manager(for purpose: PermissionPurpose) -> DirectoryManager.Type {
        switch purpose {
        case .read:
            return DirectoryManager.self
        case .write:
            return DirectoryManager.self
        }
    }
    
    
    public func title(for purpose: PermissionPurpose) -> String {
        switch purpose {
        case .read:
            return MySwiftAppToolsL10n.authReadTitle.toPackageNSLocalizedString
        case .write:
            return MySwiftAppToolsL10n.authWriteTitle.toPackageNSLocalizedString
        }
    }
    
    public func message(for purpose: PermissionPurpose) -> String {
        switch purpose {
        case .read:
            return MySwiftAppToolsL10n.authReadMsg.toPackageNSLocalizedString
        case .write:
            return MySwiftAppToolsL10n.authWriteMsg.toPackageNSLocalizedString
        }
    }
}
