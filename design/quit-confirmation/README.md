# 退出确认框为什么"点不动" — 排查与决策日志（v1.28.2）

现象：在菜单栏面板里对某个应用点「退出」，确认弹窗出现，但**鼠标一移过去弹窗就没了**，
所以永远点不到它。v1.28.0 引入这层二次确认，v1.28.2 修好宿主。

## 判别性观测（先于任何解释）

| 观测 | 排除掉的可能 |
|---|---|
| 主窗口里同款确认框（详情页 / 概览页）能正常点 | SwiftUI 代码本身、action 连线、按钮 role 都没坏，差异只在宿主容器 |
| 弹窗刚出现时面板还在，是**鼠标移动**之后才消失 | 触发量是"指针移动/悬停变化"，不是"呈现"这件事 |
| 键盘 Esc 能取消，Return 无效 | 模态会话进得去、连线是通的；Return 只是系统没给 destructive 角色绑默认按钮 |

## 三轮实验

探针都是自终止程序（7~9 s），不改 `Sources/`，在真机执行通道跑。
沙箱内没有 WindowServer，任何 GUI 探针直接 `Abort trap: 6`，所以只能走主机执行。

| 文件 | 内容 | 结论 |
|---|---|---|
| `probes/2026-11-09-window-state-probe.swift` | 复制真机形状（`.transient` 面板 + `NSHostingView` + `confirmationDialog`）， dump 窗口清单 / `CGWindowList` / runloop 模式 | 弹窗期间 runloop 恒为 `kCFRunLoopDefaultMode`；无 `NSEventTrackingRunLoopMode`；`modalWindow=nil`；面板不关 |
| `logs/2026-11-09-run_*.log` | 同探针的 6 组模式：`transient` / `flip`(→applicationDefined) / `closefirst` / `mainwindow` / `titledaccessory` / `sheets` | 六组指标**完全一致**，没有复现故障 |
| `probes/2026-11-09-windowserver-dumper.swift` | 跨进程读 WindowServer 的层级/前后顺序 + 截屏，在真机故障现场取证 | **采到了补丁前的现场**（`logs/2026-11-09-real_dump2.log`，跑满 200 s / 10 帧）：面板 `386x546@(1375,24)` 与弹窗 `410x289@(1363,152)` 同为 layer=25，且弹窗在 CG 前后顺序里排在面板**之前** —— 弹窗确实盖在上面，z-order 不是原因；弹窗出现后约 0.6 s 即消失，200 s 内重复 3 次，其中一帧 `alpha=0.33` 正在淡出。首跑 `real_dump.log` 因输出目录未建只留一帧，属无效样本 |
| `logs/2026-11-09-hover_*.log`、`logs/2026-11-09-hov2_*.log` | 加 `CGWarpMouseCursorPosition` 把光标搬到弹窗按钮上，五组行为模式各跑一遍 | 光标确实落在弹窗内（`NSEvent.mouseLocation`、`alert.mouseLocationOutsideOfEventStream`、`keyWindow=_NSAlertPanel` 三重印证），弹窗仍不消失 |
| `probes/2026-11-09-hover-gate-control.swift` | **决定性对照**：同一面板、同一 `.transient`，只改弹窗挂在哪 —— `gated` 照抄 `IconRow` 的 `if isHovered`，`hoisted` 挂到稳定祖先 | `gated`：取消 hover 后 `alertWindows=0`，且 `showConfirm` 被 SwiftUI **写回 false**；`hoisted`：弹窗继续存活、`showConfirm` 保持 true |
| `logs/2026-11-09-hg_gated.log` / `logs/2026-11-09-hg_hoisted.log` | 上面对照的两份原始输出 | 根因与修法同时被证实 |

## 被实测否掉的两条误判（都曾写进中间结论）

1. **「`.transient` 的事件跟踪会话吞掉了鼠标事件」** —— 否掉：弹窗存续期间 runloop 一直是
   default mode，没有事件跟踪模式，也没有模态会话；`.transient` / `.applicationDefined` /
   `.semitransient` 三组逐指标一致。也就是说改 `NSPopover.behavior` 这条"最像合理"的修法
   （当时的方案 A）根本无效，是探针把它证伪的。
2. **「`_NSGlassEffectWindow` 盖住 `_NSAlertPanel`，hitTest 截胡点击」** —— 否掉：这只玻璃
   子窗在**能正常点击**的主窗口对照组里同样存在、同样盖着 alert，不是判别量。当时用
   AppKit 自己的 `hitTest` 得到的"事件解析不到 alert"看起来像实锤，其实两边都解析不到，
   说明该指标不区分好坏状态。

   跨进程取证的现场数据又独立否掉了一次：真机上弹窗在 WindowServer 的前后顺序里排在
   面板之前、几何上也覆盖在面板之上，"被面板挡住"从一开始就不成立。

## 根因

`.confirmationDialog` 挂在**会离开视图树的视图**上。`PopoverView.IconRow` 的动作按钮被
`if isHovered` 门控，弹窗修饰符骑在其中的 Quit 按钮上；鼠标移向弹窗必然先离开那一行，
`onHover` 把 `isHovered` 翻 false，整个分支（连同承载弹窗的按钮）被移出视图树，SwiftUI
当场撤销呈现并把 `isPresented` 写回 false —— 探针日志里可以直接看到 `showConfirm` 由
true 变 false。弹窗因此"秒消失"，而这一步恰好发生在鼠标前往弹窗的路上。

不变量：**presentation 修饰符（`confirmationDialog` / `sheet` / `alert`）必须待在永不被
条件移除的稳定祖先上。**

## 修法（已落地）

- `PopoverView` 持有单一 `pendingQuitTarget: MenuBarMonitor.MenuBarItem?`，弹窗挂在面板根容器；
  形状与 `ContentView` 已有的 `residentQuitTarget` 一致。
- `IconRow` 去掉自持状态，改 `let onQuit: (MenuBarMonitor.MenuBarItem) -> Void` 只上报意图；
  hover 显现的视觉与 `transition` 动画原样保留。
- 弹窗与 `MenuBarMonitor.quitApp` 一并在 `#if !MAC_APP_STORE` 内：MAS 通道把该方法编译掉，
  挂到根之后若不同步门控，MAS 构建会引用不存在的符号。**这一步是实测出来的**——
  先单独验证 `#if` 放在 modifier 链里在两个通道下都能编译，再落地门控。
- 底栏「退出 Topiary」和主窗口两处不改宿主：`canQuit(_:)` 只是排除 Finder
  （`MenuBarMonitor.swift:482`），是数据稳定条件，不随鼠标翻转，不属于本缺陷。

## 复现命令

```bash
# 决定性对照（gated 复现故障，hoisted 修法有效）
swiftc -O -module-cache-path <cache> -o hovergate probes/2026-11-09-hover-gate-control.swift
STYLE=gated   ./HG.app/Contents/MacOS/hovergate    # 取消 hover → alertWindows=0
STYLE=hoisted ./HG.app/Contents/MacOS/hovergate    # 取消 hover → 弹窗存活

# 六组行为/宿主模式的状态 dump
MODE=transient|flip|closefirst|mainwindow|titledaccessory|sheets ./Probe.app/Contents/MacOS/probe

# 跨进程窗口层级取证
./out/windowdump Topiary 150 <输出目录>
```

探针源码里的 `Probe.app` / `HG.app` 打包壳不在档内（只有 Info.plist 模板价值），
需要的最小条件：`LSUIElement=true` + `NSApp.setActivationPolicy(.accessory)`。

## 方法论（下次直接照做）

- **探针必须包含真实指针移动/悬停。** 只用定时器翻状态的探针会让所有模式表现一致，
  给出假的"复现失败"——本次前两轮就是这么白跑的。
- 工具回执"已拒绝/已超时"**不等于**命令没跑。本次那条被标记为拒绝的现场取证命令在主机
  上跑满了 200 s 并留下了完整日志，我先把它判成无效样本、后来才从 mtime 和内容里发现——
  凡有落盘产物，都要按产物核对，别按回执下结论。
- 找一个**能区分好坏状态的指标**再下结论；两边数值相同的指标（如本次的 hitTest 解析）
  不是证据。
- 优先在源码里找**能直接证死的结构条件**（本例的 `if isHovered` 包住 presentation），
  比不断给探针加特征瞎猜便宜得多。
- `CGWarpMouseCursorPosition` 会移动光标、更新 `NSEvent.mouseLocation`，但**未必投递
  `mouseMoved`**；要模拟悬停，直接程序化翻转对应的状态条件更接近真相。真指针流的最终
  判定来自真机验收。

## 未证实 / 遗留

- 只在 macOS 27.2 实测。macOS 14/15 未验证；机制是纯视图树逻辑、与系统版本无关，
  这句属于**推定**。
- 真机验收目前覆盖了「鼠标移到弹窗上不再消失、可正常点击」；取消路径、跨行标题跟随、
  底栏回归项在验收清单里，见 CHANGELOG v1.28.2。
- 不变量尚无自动化检查：可以做一个便宜的 CI 结构检查（凡 presentation 修饰符落在
  `if <条件>` 内即失败），本次未做。
