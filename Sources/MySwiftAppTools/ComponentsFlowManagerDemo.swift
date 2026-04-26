//
//  ComponentsFlowManagerDemo.swift
//  VideoHero
//
//  Created by yangxuehui on 2026/4/3.
//

import SwiftUI

/// 页面中所有可参与联动的组件 ID。
/// 建议使用枚举，而不是直接用字符串，避免拼写错误。
enum DemoComponentID: String, CaseIterable, Hashable {
    case a
    case b
    case c
    case d
    case e
    case f
}

/// 组件所属分组。
/// 分组主要用于两类规则：
/// 1. 组内互斥
/// 2. 组间依赖
enum DemoGroupID: String, Hashable {
    case primaryFlow
    case secondaryFlow
    case extraFlow
}

struct ComponentsFlowManagerDemo: View {
    /// 每个页面维护自己独立的一份联动状态。
    /// 这样页面之间不会互相污染状态，也不依赖单例。
    @State private var store = ComponentsFlowManager<DemoComponentID, DemoGroupID>()

    var body: some View {
        VStack(spacing: 16) {
            Text("组件联动 Demo")
                .font(.title2)
                .bold()

            groupSection(title: "第一组", componentIDs: [.a, .b])
            groupSection(title: "附加组", componentIDs: [.c, .d])
            groupSection(title: "第二组", componentIDs: [.e, .f])

            Divider()

            Button("重置全部状态") {
                store.resetAll()
            }
        }
        .padding()
        .task {
            configureRulesIfNeeded()
            registerComponentsIfNeeded()
        }
    }

    /// 配置当前页面需要的联动规则。
    /// 为了避免视图重复刷新时多次追加规则，这里只在尚未配置时初始化一次。
    private func configureRulesIfNeeded() {
        guard store.rules.isEmpty else { return }

        store.setRules([
            AnyInteractionRule(
                GroupMutualExclusionRule<DemoComponentID, DemoGroupID>(
                    enabledGroups: [.primaryFlow, .secondaryFlow]
                )
            ),
            AnyInteractionRule(
                GroupDependencyRule<DemoComponentID, DemoGroupID>(
                    dependencies: [
                        .secondaryFlow: [.primaryFlow]
                    ]
                )
            ),
            AnyInteractionRule(
                BusySourceDisablesTargetsRule<DemoComponentID, DemoGroupID>(
                    items: [
                        .init(source: .f, targets: [.a, .b, .c, .d])
                    ]
                )
            )
        ])
    }

    /// 渲染一个分组区域。
    @ViewBuilder
    private func groupSection(title: String, componentIDs: [DemoComponentID]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            ForEach(componentIDs, id: \.self) { componentID in
                componentRow(componentID)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 渲染单个组件行。
    /// 同时展示按钮和当前状态，方便调试联动逻辑。
    @ViewBuilder
    private func componentRow(_ componentID: DemoComponentID) -> some View {
        let currentState = store.state(of: componentID) ?? .init()
        let enabled = store.isEnabled(componentID)

        HStack(spacing: 12) {
            Button(title(for: componentID)) {
                handleTap(componentID)
            }
            .disabled(!enabled)
            .buttonStyle(.borderedProminent)

            Text("busy: \(currentState.isBusy ? "true" : "false")")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("finished: \(currentState.isFinished ? "true" : "false")")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("enabled: \(enabled ? "true" : "false")")
                .font(.caption)
                .foregroundStyle(enabled ? .green : .red)
        }
    }

    /// 首次进入页面时注册组件。
    /// 为了避免重复注册，这里做一次保护。
    private func registerComponentsIfNeeded() {
        guard store.allComponents().isEmpty else { return }

        store.register([
            (.a, .primaryFlow, .init()),
            (.b, .primaryFlow, .init()),
            (.c, .extraFlow, .init()),
            (.d, .extraFlow, .init()),
            (.e, .secondaryFlow, .init()),
            (.f, .secondaryFlow, .init())
        ])
    }

    /// 统一处理组件点击。
    /// 实际项目里也可以把每个按钮拆成单独方法。
    private func handleTap(_ componentID: DemoComponentID) {
        switch componentID {
        case .a:
            startTask(for: .a, markFinishedWhenDone: true)

        case .b:
            startTask(for: .b, markFinishedWhenDone: true)

        case .c:
            startTask(for: .c, markFinishedWhenDone: false)

        case .d:
            startTask(for: .d, markFinishedWhenDone: false)

        case .e:
            startTask(for: .e, markFinishedWhenDone: false)

        case .f:
            startTask(for: .f, markFinishedWhenDone: false)
        }
    }

    /// 模拟异步任务：
    /// 1. 点击后先置 busy = true
    /// 2. 等待一段时间模拟耗时操作
    /// 3. 结束后置 busy = false
    /// 4. 如果需要，标记为 finished
    private func startTask(for componentID: DemoComponentID, markFinishedWhenDone: Bool) {
        store.setBusy(true, for: componentID)

        Task {
            try? await Task.sleep(for: .seconds(1.2))

            store.setBusy(false, for: componentID)

            if markFinishedWhenDone {
                store.setFinished(true, for: componentID)
            }
        }
    }

    /// 组件标题展示。
    private func title(for componentID: DemoComponentID) -> String {
        switch componentID {
        case .a: return "A"
        case .b: return "B"
        case .c: return "C"
        case .d: return "D"
        case .e: return "E"
        case .f: return "F"
        }
    }
}

#Preview {
    ComponentsFlowManagerDemo()
}
