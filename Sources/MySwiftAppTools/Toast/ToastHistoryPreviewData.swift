//
//  ToastHistoryPreviewData.swift
//  MySwiftAppTools
//
//  仅供 Xcode Preview 使用的样本数据。
//
//  三条设计约束：
//  1. 时间全部按「相对当前时刻」推算，因此无论哪天打开 Preview，「今天 / 昨天 / N月N日」分组都成立。
//  2. 使用 `deferredPersist = true` 构造，样本数据只存在于内存，**不会写进真实 UserDefaults**。
//  3. 整份文件包在 `#if DEBUG` 内，Release 构建完全不参与编译。
//

#if DEBUG
import Foundation

/// Toast 历史界面的样本数据。
@MainActor
enum ToastHistoryPreviewData {

    // MARK: - 单条样本

    struct Sample {
        let date: Date
        let type: ToastType
        let message: String
    }

    // MARK: - 构造入口

    /// 完整样本：42 条，跨 6 个自然日，覆盖全部 5 种类型。
    ///
    /// 用于验证：分页（每屏 20 条 + 更多）、日期分组吸顶、悬停删除、清空二次确认、长文本折行。
    static func makeStore() -> ToastHistoryStore {
        makeStore(samples: fullSamples)
    }

    /// 少量样本：6 条，不足一屏，用于确认「更多」按钮不出现。
    static func makeShortStore() -> ToastHistoryStore {
        makeStore(samples: Array(fullSamples.suffix(6)))
    }

    /// 空状态样本。
    static func makeEmptyStore() -> ToastHistoryStore {
        makeStore(samples: [])
    }

    /// 组装存储。
    ///
    /// - Parameter samples: 样本数组，内部会按时间升序重排后依次喂入。
    static func makeStore(samples: [Sample]) -> ToastHistoryStore {
        let store = ToastHistoryStore()
        store.configure(
            maxCount: 500,
            isHistoryEnabled: true,
            excludedTypes: [],        // 放开 loading，便于看到全部类型
            maxMessageLength: 2000,   // 放宽存储截断，让长文本走展示层折行，两者区分清楚
            maxTotalBytes: 512 * 1024,
            deferredPersist: true     // 关键：只写内存，不碰 UserDefaults
        )
        // 清掉 init 时从磁盘读进来的真实数据。此时 deferredPersist 已生效，只动内存。
        store.clearAll()

        // 按时间升序喂入：store 内部每次 insert(at: 0)，最终自然形成「新 → 旧」。
        for sample in samples.sorted(by: { $0.date < $1.date }) {
            store.record(
                ToastItem(
                    message: sample.message,
                    createdAt: sample.date,
                    type: sample.type,
                    position: .top,
                    customIcon: nil,
                    requireConfirm: false,
                    onConfirm: nil
                )
            )
        }

        return store
    }

    // MARK: - 时间构造

    private static var calendar: Calendar { .current }

    /// N 分钟前。用于展示「刚刚 / N 分钟前」。
    private static func ago(_ minutes: Int) -> Date {
        Date().addingTimeInterval(-Double(minutes) * 60)
    }

    /// `daysAgo` 天前的 `hour:minute`。用于构造历史日期分组。
    private static func daysAgo(_ daysAgo: Int, _ hour: Int, _ minute: Int) -> Date {
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }

    private static func at(_ date: Date, _ type: ToastType, _ message: String) -> Sample {
        Sample(date: date, type: type, message: message)
    }

    // MARK: - 完整样本（按时间由旧到新书写）

    /// 42 条样本，跨 6 个自然日。
    ///
    /// 条数刻意设计成：今天 9 条 + 昨天 11 条 = 20 条，
    /// 首屏刚好停在自然日边界上，点「更多」继续加载前天的分组。
    static let fullSamples: [Sample] = {

        // ── 去年（验证「2025年N月N日 星期X」完整格式）──
        let lastYear: [Sample] = [
            at(daysAgo(400, 9, 12), .success, "已完成 128 个文件的批量重命名"),
            at(daysAgo(400, 9, 40), .warning, "有 3 个文件名包含非法字符，已自动替换为下划线"),
            at(daysAgo(400, 10, 5), .error, "导出失败：目标磁盘空间不足，需要至少 1.2 GB 可用空间"),
        ]

        // ── 40 天前（验证「N月N日 星期X」格式）──
        let longAgo: [Sample] = [
            at(daysAgo(40, 8, 30), .normal, "已切换到深色主题"),
            at(daysAgo(40, 11, 2), .warning, "所选文件夹为空，没有可处理的文件"),
            at(daysAgo(40, 14, 18), .success, "已载入 2,480 条记录"),
            at(daysAgo(40, 16, 45), .error, "网络请求超时（30 秒），请检查网络后重试"),
            at(daysAgo(40, 19, 20), .success, "已导出 36 个文件到「导出」文件夹"),
            at(daysAgo(40, 21, 8), .normal, "设置已重置为默认值"),
        ]

        // ── 8 天前 ──
        let weekAgo: [Sample] = [
            at(daysAgo(8, 9, 15), .warning, "重命名冲突：2 个文件重名，已自动追加序号"),
            at(daysAgo(8, 10, 40), .loading, "正在生成预览…"),
            at(daysAgo(8, 10, 52), .success, "预览已生成，共 12 页"),
            at(daysAgo(8, 13, 26), .error, "权限不足：请在「系统设置 → 隐私与安全性」中授予访问权限"),
            at(daysAgo(8, 15, 3), .normal, "已复制文件路径到剪贴板"),
            at(daysAgo(8, 17, 41), .normal, "已还原上一步操作"),
        ]

        // ── 前天 ──
        let twoDaysAgo: [Sample] = [
            at(daysAgo(3, 8, 55), .normal, "检测到 1 项待处理更新"),
            at(daysAgo(3, 9, 30), .success, "下载完成：3 个更新包，共 86.4 MB"),
            at(daysAgo(3, 11, 12), .warning, "部分文件被跳过：格式不受支持"),
            at(daysAgo(3, 14, 5), .error, "校验失败：文件已损坏或下载不完整"),
            at(daysAgo(3, 16, 48), .success, "已完成校验，全部文件完好"),
            at(daysAgo(3, 18, 22), .normal, "已忽略本次更新"),
            at(daysAgo(3, 20, 10), .normal, "窗口布局已保存"),
        ]

        // ── 昨天（11 条）──
        let yesterday: [Sample] = [
            at(daysAgo(1, 8, 20), .normal, "应用已启动，共载入 1,286 个文件"),
            at(daysAgo(1, 9, 5), .success, "保存成功"),
            at(daysAgo(1, 10, 33), .error, "写入失败：目标文件被其他程序占用"),
            at(daysAgo(1, 11, 47), .loading, "正在压缩 42 个文件…"),
            at(daysAgo(1, 12, 2), .success, "压缩完成，输出 38.4 MB"),
            at(daysAgo(1, 13, 55), .normal, "已取消操作"),
            at(daysAgo(1, 15, 18), .warning, "检测到 1 个文件格式不受支持，已跳过"),
            at(daysAgo(1, 16, 40), .success, "多行文本样本：\n成功 36 个\n跳过 2 个\n失败 1 个"),
            at(daysAgo(1, 18, 9), .normal, "已更新为 2.4.1 版本"),
            at(daysAgo(1, 20, 30), .success, "反馈已发送，感谢你的建议"),
            at(daysAgo(1, 22, 14), .warning, "请先选择需要处理的文件夹"),
        ]

        // ── 今天（9 条，由新到旧书写后反转，见返回值）──
        // 全部用「N 分钟前」推算，保证既不会出现未来时间，顺序也天然递减。
        let today: [Sample] = [
            at(ago(0), .success, "已复制 3 个文件路径到剪贴板"),
            at(ago(2), .normal, "已切换到浅色主题"),
            at(ago(6), .warning, "请先选择需要处理的文件夹"),
            at(ago(14), .success, "保存成功"),
            at(ago(27), .error, "导出失败：目标磁盘空间不足，需要至少 1.2 GB 可用空间"),
            at(ago(48), .success, "已完成 128 个文件的批量重命名"),
            at(ago(95), .normal, "长文本样本：这是一条较长的提示消息，用于验证折行与三行截断效果。文本长度必须足够长，才能触发 lineLimit 的截断逻辑，从而确认末尾的省略号显示是否正确。"),
            at(ago(180), .loading, "正在生成预览…"),
            at(ago(320), .normal, "超长连续字符样本（长文件路径不应撑破布局）：/Users/example/Library/Application Support/com.example.app/Cache/Downloads/archive-2026-09-20T22-41-03Z-full-backup.tar.zst"),
        ]

        return lastYear + longAgo + weekAgo + twoDaysAgo + yesterday + today
    }()
}

#endif
