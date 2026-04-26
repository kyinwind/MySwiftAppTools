/*
 ComponentsFlowManager.swift
 VideoHero

 这个工具类专门管理一个窗口中多个组件之间的联动关系。
 通过这个工具类统一管理，可以做到：

 1. 对组件进行分组
 2. A 分组的组件都 ready 后，B 分组才能可用
 3. A 分组内只能有一个组件在执行任务，执行任务期间，其他组件不可用

 Created by yangxuehui on 2026/4/3.
*/

import Foundation
import Observation

/// 单个组件的业务状态。
/// 这里先只放两个最常见的维度：
/// - isBusy: 是否正在执行
/// - isFinished: 是否已完成
///
/// 后续如果你有更多状态，比如失败、暂停、校验中，
/// 可以继续往这里扩展。
struct ComponentState: Equatable {
    /// 当前组件是否处于忙碌状态。
    /// 例如点击按钮后请求接口，请求结束前设为 true。
    var isBusy: Bool = false

    /// 当前组件对应的流程是否完成。
    /// 例如 A、B 都完成后，才能解锁 E、F。
    var isFinished: Bool = false
}

/// 管理器内部保存的组件节点。
/// 工具类本身不关心具体组件长什么样，只关心：
/// - 它属于哪个组
/// - 它当前是什么状态
struct ComponentNode<GroupID: Hashable>: Equatable {
    let groupID: GroupID
    var state: ComponentState
}

/// 规则计算时使用的上下文。
/// 规则只读取这个上下文，不直接依赖 Store 内部实现，
/// 这样规则更独立，也更容易单测。
struct InteractionContext<ComponentID: Hashable, GroupID: Hashable> {
    /// 当前所有组件的快照。
    let components: [ComponentID: ComponentNode<GroupID>]

    /// 读取某个组件的状态。
    func state(of componentID: ComponentID) -> ComponentState? {
        components[componentID]?.state
    }

    /// 读取某个组件所在分组。
    func group(of componentID: ComponentID) -> GroupID? {
        components[componentID]?.groupID
    }

    /// 获取某个分组下的所有组件 ID。
    func componentIDs(in groupID: GroupID) -> [ComponentID] {
        components.compactMap { id, node in
            node.groupID == groupID ? id : nil
        }
    }

    /// 获取某个分组下的所有节点。
    func nodes(in groupID: GroupID) -> [ComponentNode<GroupID>] {
        components.values.filter { $0.groupID == groupID }
    }

    /// 判断某个分组中，除了当前组件外，是否还有其他组件正在忙。
    /// 常用于“组内互斥”。
    func isAnyOtherComponentBusy(
        in groupID: GroupID,
        excluding componentID: ComponentID
    ) -> Bool {
        components.contains { id, node in
            id != componentID &&
            node.groupID == groupID &&
            node.state.isBusy
        }
    }

    /// 判断某个分组是否已完成。
    /// 当前默认策略是：组内所有组件都 finished，才算该组完成。
    ///
    /// 如果以后你想改成：
    /// - 组内任意一个完成即可
    /// - 指定组件完成即可
    /// 可以把这里继续抽象成策略。
    func isGroupFinished(_ groupID: GroupID) -> Bool {
        let groupNodes = nodes(in: groupID)

        // 空组默认不算完成。
        guard !groupNodes.isEmpty else { return false }

        return groupNodes.allSatisfy { $0.state.isFinished }
    }
}

/// 联动规则协议。
/// 每条规则只负责判断：
/// “某个组件在当前上下文下，是否允许可用”。
///
/// 多条规则会叠加：
/// 只有全部规则都返回 true，组件才可用。
protocol InteractionRule {
    associatedtype ComponentID: Hashable
    associatedtype GroupID: Hashable

    func allows(
        componentID: ComponentID,
        context: InteractionContext<ComponentID, GroupID>
    ) -> Bool
}

/// 由于带 associatedtype 的协议不能直接作为普通数组元素使用，
/// 这里用一个类型擦除包装，把不同规则统一收口成同一种类型。
struct AnyInteractionRule<ComponentID: Hashable, GroupID: Hashable> {
    private let allowsClosure: (ComponentID, InteractionContext<ComponentID, GroupID>) -> Bool

    init<R: InteractionRule>(_ rule: R)
    where R.ComponentID == ComponentID, R.GroupID == GroupID {
        self.allowsClosure = rule.allows
    }

    func allows(
        componentID: ComponentID,
        context: InteractionContext<ComponentID, GroupID>
    ) -> Bool {
        allowsClosure(componentID, context)
    }
}

/// 规则1：同组互斥。
/// 含义：
/// - 当前组件自己 busy 时，不允许再次点击
/// - 同组里只要有其他组件 busy，当前组件也不可用
///
/// 这个规则支持按分组启用：
/// - `enabledGroups == nil` 时，表示所有分组都启用组内互斥
/// - `enabledGroups` 有值时，表示只有指定分组启用组内互斥
struct GroupMutualExclusionRule<ComponentID: Hashable, GroupID: Hashable>: InteractionRule {
    /// 需要启用组内互斥的分组集合。
    /// 传 nil 表示所有分组都启用。
    let enabledGroups: Set<GroupID>?

    init(enabledGroups: Set<GroupID>? = nil) {
        self.enabledGroups = enabledGroups
    }

    func allows(
        componentID: ComponentID,
        context: InteractionContext<ComponentID, GroupID>
    ) -> Bool {
        guard let groupID = context.group(of: componentID) else {
            return false
        }

        // 如果当前规则只对部分分组生效，而当前组件所在分组不在范围内，
        // 则直接放行，不参与组内互斥判断。
        if let enabledGroups, !enabledGroups.contains(groupID) {
            return true
        }

        // 自己正在执行时，通常不允许重复点击。
        if context.state(of: componentID)?.isBusy == true {
            return false
        }

        // 同组有其他组件在执行，则当前组件禁用。
        return !context.isAnyOtherComponentBusy(in: groupID, excluding: componentID)
    }
}

/// 规则2：组依赖。
/// 含义：
/// 某个组想可用，必须先满足它依赖的前置组都已经完成。
struct GroupDependencyRule<ComponentID: Hashable, GroupID: Hashable>: InteractionRule {
    /// key: 当前组
    /// value: 当前组依赖的前置组集合
    let dependencies: [GroupID: Set<GroupID>]

    func allows(
        componentID: ComponentID,
        context: InteractionContext<ComponentID, GroupID>
    ) -> Bool {
        guard let groupID = context.group(of: componentID) else {
            return false
        }

        let requiredGroups = dependencies[groupID] ?? []

        for requiredGroup in requiredGroups {
            if !context.isGroupFinished(requiredGroup) {
                return false
            }
        }

        return true
    }
}

/// 规则3：来源组件 busy 时，禁用指定目标组件。
struct BusySourceDisablesTargetsRule<ComponentID: Hashable, GroupID: Hashable>: InteractionRule {
    /// 单条映射规则。
    struct Item {
        /// 来源组件。
        let source: ComponentID

        /// 当 source busy 时，需要被禁用的目标组件。
        let targets: Set<ComponentID>
    }

    let items: [Item]

    func allows(
        componentID: ComponentID,
        context: InteractionContext<ComponentID, GroupID>
    ) -> Bool {
        for item in items {
            // 当前组件不在目标集合中，就不用管这条规则。
            guard item.targets.contains(componentID) else { continue }

            // 只要来源组件正在忙，当前目标组件就不可用。
            if context.state(of: item.source)?.isBusy == true {
                return false
            }
        }

        return true
    }
}

/// SwiftUI 场景下的交互联动状态中心。
///
/// 它负责：
/// - 注册页面有哪些组件
/// - 保存每个组件当前状态
/// - 保存联动规则
/// - 对外计算某个组件当前是否可用
///
/// 使用 @MainActor 的原因：
/// SwiftUI 的状态更新和界面刷新都应发生在主线程。
@Observable
final class ComponentsFlowManager<ComponentID: Hashable, GroupID: Hashable> {
    /// 当前页面中已注册的组件集合。
    var components: [ComponentID: ComponentNode<GroupID>] = [:]

    /// 当前启用的联动规则。
    var rules: [AnyInteractionRule<ComponentID, GroupID>] = []

    init(rules: [AnyInteractionRule<ComponentID, GroupID>] = []) {
        self.rules = rules
    }

    // 显式 nonisolated deinit，绕过 Swift 6.3 编译器 WMO EarlyPerfInliner crash
    nonisolated deinit {
        // components 和 rules 会自动释放，无需手动清理
    }

    // MARK: - 注册

    /// 注册单个组件。
    /// 页面初始化时，把参与联动的组件都注册进来。
    func register(
        _ componentID: ComponentID,
        groupID: GroupID,
        initialState: ComponentState = .init()
    ) {
        components[componentID] = ComponentNode(
            groupID: groupID,
            state: initialState
        )
    }

    /// 批量注册组件。
    /// 适合页面首次进入时统一初始化。
    func register(
        _ items: [(componentID: ComponentID, groupID: GroupID, initialState: ComponentState)]
    ) {
        for item in items {
            components[item.componentID] = ComponentNode(
                groupID: item.groupID,
                state: item.initialState
            )
        }
    }

    /// 取消注册组件。
    /// 如果你的页面组件是动态出现或销毁的，这个方法会有用。
    func unregister(_ componentID: ComponentID) {
        components.removeValue(forKey: componentID)
    }

    // MARK: - 规则配置

    /// 替换全部规则。
    /// 一般在页面初始化时调用一次即可。
    func setRules(_ rules: [AnyInteractionRule<ComponentID, GroupID>]) {
        self.rules = rules
    }

    /// 追加单条规则。
    func addRule(_ rule: AnyInteractionRule<ComponentID, GroupID>) {
        rules.append(rule)
    }

    // MARK: - 状态更新

    /// 设置某个组件是否忙碌。
    /// 常用于点击后开启异步任务。
    func setBusy(_ isBusy: Bool, for componentID: ComponentID) {
        guard var node = components[componentID] else { return }
        node.state.isBusy = isBusy
        components[componentID] = node
    }

    /// 设置某个组件是否完成。
    /// 常用于某个关键步骤执行成功后，解锁后续流程。
    func setFinished(_ isFinished: Bool, for componentID: ComponentID) {
        guard var node = components[componentID] else { return }
        node.state.isFinished = isFinished
        components[componentID] = node
    }

    /// 通用状态更新入口。
    /// 当状态字段逐渐变多时，这个方法更灵活。
    func updateState(
        for componentID: ComponentID,
        mutate: (inout ComponentState) -> Void
    ) {
        guard var node = components[componentID] else { return }
        mutate(&node.state)
        components[componentID] = node
    }

    /// 重置单个组件状态。
    func reset(_ componentID: ComponentID) {
        guard var node = components[componentID] else { return }
        node.state = .init()
        components[componentID] = node
    }

    /// 重置全部组件状态。
    func resetAll() {
        for key in components.keys {
            components[key]?.state = .init()
        }
    }

    // MARK: - 查询

    /// 查询某个组件当前是否可用。
    /// SwiftUI 视图层通常会直接拿它驱动 `.disabled(...)`。
    func isEnabled(_ componentID: ComponentID) -> Bool {
        guard components[componentID] != nil else {
            return false
        }

        let context = InteractionContext(components: components)
        return rules.allSatisfy { $0.allows(componentID: componentID, context: context) }
    }

    /// 查询某个组件当前状态。
    func state(of componentID: ComponentID) -> ComponentState? {
        components[componentID]?.state
    }

    /// 查询某个分组是否已完成。
    func isGroupFinished(_ groupID: GroupID) -> Bool {
        let context = InteractionContext(components: components)
        return context.isGroupFinished(groupID)
    }

    /// 返回当前全部组件，便于调试或列表展示。
    func allComponents() -> [ComponentID: ComponentNode<GroupID>] {
        components
    }
}
