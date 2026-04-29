import Foundation
import ServiceManagement


/// 自动启动管理器
/// 使用 `SMAppService.mainApp` 管理 macOS 登录项。
///
/// 使用方式：
///
/// ```swift
/// let isOn = AutoLaunchManager.shared.isEnabled
/// AutoLaunchManager.shared.setEnabled(true)
/// AutoLaunchManager.shared.toggle()
/// ```
///
/// 注意：
/// - `MySwiftAppTools` 当前最低支持 macOS 14，因此这里不再兼容旧的 `LSSharedFileList` API。
/// - 登录项能力依赖真实 App bundle，在 Swift Package 测试 target 或命令行工具中只能用于编译验证。
@MainActor
public final class AutoLaunchManager {
    public static let shared = AutoLaunchManager()

    public init() {}

    /// 是否已启用自动启动
    public var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// 启用自动启动
    @discardableResult
    public func enable() -> Bool {
        do {
            try SMAppService.mainApp.register()
            Log.info("AutoLaunch enabled successfully")
            return true
        } catch {
            Log.error("Failed to enable AutoLaunch: \(error)")
            return false
        }
    }

    /// 禁用自动启动
    @discardableResult
    public func disable() -> Bool {
        do {
            try SMAppService.mainApp.unregister()
            Log.info("AutoLaunch disabled successfully")
            return true
        } catch {
            Log.error("Failed to disable AutoLaunch: \(error)")
            return false
        }
    }

    /// 按目标状态设置自动启动。
    @discardableResult
    public func setEnabled(_ enabled: Bool) -> Bool {
        enabled ? enable() : disable()
    }

    /// 切换自动启动状态
    @discardableResult
    public func toggle() -> Bool {
        if isEnabled {
            return disable()
        } else {
            return enable()
        }
    }
}
