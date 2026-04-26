# RCM Design System

这套文件不是为了替代你现有的 `ThemeManager.swift`，而是补上一层更稳定的视觉基础设施。

## 文件职责

- `RCMDesignTokens.swift`
  颜色、间距、圆角、排版、控件尺寸。
- `RCMText.swift`
  页面标题、分区标题、辅助文字、等宽文本。
- `RCMButtons.swift`
  主按钮、次按钮、弱按钮、危险按钮、状态标签。
- `RCMSurfaces.swift`
  卡片、分区卡片、Hero 面板。
- `RCMRows.swift`
  设置行、键值行、带标签的输入区域。

## 建议接入顺序

1. 先在 `PurchaseView` 和 `About` 页替换按钮、标题、卡片。
2. 再把 `DirectorySettingsView`、`QuickAppsSettingsView`、`UserFileTypeListView` 换成 `RCMPageSection + RCMSettingRow`。
3. 最后再考虑把 `ThemeManager.swift` 里真正通用的组件逐步迁出。

## 一个简单示例

```swift
VStack(alignment: .leading, spacing: RCMSpacing.xl) {
    RCMPageTitle("目录权限设置", subtitle: "请选择文件复制功能使用的目标目录。")

    RCMPageSection("已授权目录") {
        RCMSettingRow("Documents", subtitle: "/Users/name/Documents") {
            RCMStatusBadge("已授权", tone: .success)
        }
    }

    HStack {
        Button("新增") { }
            .rcmButton(.primary)

        Button("删除") { }
            .rcmButton(.subtle)
    }
}
.padding(RCMSpacing.xxl)
```
