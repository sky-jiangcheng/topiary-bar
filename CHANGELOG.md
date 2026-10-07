# Changelog

> 🌐 [English](README.md) · [简体中文](README.zh-CN.md)

所有 notable 变更记录于此；各版本产物见 [GitHub Releases](https://github.com/sky-jiangcheng/topiary-bar/releases)。

| 版本 | 内容 |
|------|------|
| v1.26.4 | 第三方应用 Quit 响应优化：`NSRunningApplication.terminate()` 推到独立 `Task.detached`，主线程不再同步等待 Apple Event 回复，多个进程并行触发，单个卡死不再阻塞整批；点击 Quit 瞬间从列表移除行（不再等下一个 timer tick，最坏 2s 延迟）；新增 `quittingBundleIDs` 去重同一 app 的重复 Quit 点击、阻止 timer tick 把还在 running 的 app 加回列表（行不会"又出现"）；escalate grace period 3 s → 1.5 s；监听 `NSWorkspace.didTerminateApplicationNotification` / `didLaunchApplicationNotification` 事件驱动刷新（第三方 app 启动/退出时列表立即更新，不再等 timer）；提取 `visibleItems(_:suppressing:)` 纯函数 + 4 个新单元测试覆盖抑制/去重/未知 bundle ID 路径 |
| v1.26.3 | 修复同一应用在列表中重复出现：一个进程 ≠ 一个应用——Docker Desktop 的 `com.docker.backend` 与 `com.docker.virtualization` 等多进程共享同一 bundle ID，此前逐进程建条目导致 Status Bar 列表出现两行 Docker（Hidden Bar 同理）；现按 bundle ID 去重合并，一个应用一行，合并条目的内存为全部进程之和、PID 取最早启动的进程；同一 bundle ID 同时存在 regular 与 accessory 进程时按 Dock 应用归类，避免两个分区出现相同 id；「退出」升级为终止该 bundle ID 的全部进程（3 秒后对存活者升级强杀）；修复概览页 `Dictionary(uniqueKeysWithValues:)` 遇重复 id 直接崩溃的隐患；列表排序补 bundle ID 决胜，消除同名应用导致的顺序抖动 |
| v1.26.2 | 缺陷修复与合规补齐：修复内存占用与 PID 停留在首次快照（扫描去重把「内容变化」误判为「无变化」）、菜单栏图标选择与全局热键重启后丢失、清除热键后每次启动自动复活（`UserDefaults` 无法存顶层 nil，改为装箱存储）；补齐 App Store 隐私清单（`UserDefaults` 属 required-reason API，缺失会被拒审）；设置页新增热键清除按钮；应用图标与缩略图按 bundle ID 缓存（此前每 1–2 秒读盘一次）、系统内存轮询改为随弹窗显隐启停；CI 补 mas / devid 双通道编译、发布 job 绑定 environment、弃用的 `altool` 换为 `iTMSTransporter`；修正官网与 README 中已删除功能的描述及一处 404 链接 |
| v1.26.1 | 主窗口标题栏去重（原生窗口标题 + 小图标 + 切换器，不再重复品牌名）；概览页新增「常驻应用」区——常驻图标被刘海遮挡或隐藏时，可在主面板直接 退出 / 取消常驻，无需依赖那些图标，闭环补全 |
| v1.26.0 | Dock 图标与品牌强化：Dock 图标跟随主面板显隐——启动/打开主面板时显示，关闭主面板自动隐藏（可在设置永久关闭回归纯后台代理），状态栏弹窗的「打开主窗口/设置」随时重新召唤；登录时启动（SMAppService）抢占菜单栏右侧稳定位置；Dock 右键菜单品牌化（打开主窗口/设置/退出）；主窗口标题栏、概览页与弹窗头部展示真实 App 图标与完整品牌名（Brand 常量收敛）；修复弹窗设置按钮无反应（可达窗口误判为弹窗自身）；恢复弹窗底栏退出按钮；移除无用的辅助功能诊断徽章与 leaf 旧图标设计稿遗留 |
| v1.25.2 | 修复弹窗设置按钮无反应：召唤主窗口的可达窗口判定被弹窗自身窗口（约 360pt）误满足，改为按 styleMask 含 .titled 判定；弹窗底栏恢复「退出」按钮（LSUIElement 后台代理无可发现的退出入口），布局为 齿轮 / 打开主窗口 / 退出 三段式 |
| v1.25.1 | 移除图标排序功能与设置页「图标管理」区（前者唯一消费者浮动面板已删除，后者与主窗口侧栏重复）；常驻仅限菜单栏类应用——详情页开关门控，ResidentBarManager 自动清理误钉的程序坞应用（如预览/访达/活动监视器），退出清理仅保留菜单栏应用 |
| v1.25.0 | 全局快捷键可自定义：设置页新增「全局快捷键」录制器（点击后按组合键即完成更换，Esc/点击外部取消，× 禁用）；冲突检测——组合键被占用时橙色提示且热键停用直到换绑；快捷键持久化并随启动恢复，右键菜单动态展示当前组合；菜单栏图标位置持久化（⌘-拖动一次跨启动记住） |
| v1.24.0 | 架构简化：移除浮动聚合面板，常驻管理并入主窗口（详情页「常驻菜单栏」开关 + 侧栏图钉标识）；设置并入主窗口（「应用 / 设置」双标签，设置页单页化）；弹窗齿轮与右键菜单改为主窗口入口；修复侧栏筛选 Picker 泄漏的冗余「全部」标签 |
| v1.23.0 | 详情页结构化重构：左对齐定义式布局（图标/名称头部 + 类型/内存/PID 信息卡 + 动作区）；退出与强制退出合并为单个「退出」（优雅终止 3 秒未退出自动升级强杀，移除确认弹窗）；新增 canOpen/canQuit 运行态判定，无效按钮（无 bundle URL 的打开、访达的退出）不再显示；侧栏行与弹窗行统一单行结构、动作按钮带文字常驻可见；弹窗内存卡片压缩约一半 |
| v1.22.0 | 菜单栏弹窗内存洞察（参考 Lemon）：系统内存占用百分比 + 进度条 + 已用/总量；每应用内存足迹列表按占用降序（`proc_pid_rusage`，MAS 版剔除该列）；明确关闭按钮与「齿轮 / 打开主窗口 / 面板开关」三段式底部；列表行改单行、去行内类型徽章、动作按钮静止态降噪；Hidden Bar / Ice / Bartender 等隐藏工具运行时不再误报刘海遮挡，警告横幅支持手动关闭 |
| v1.21.0 | 品牌重塑：StatusBar → Topiary（仓库 / 包 / 目录更名 `topiary-bar`；App 显示名、菜单文案、CI 产物同步更名；Bundle ID 与 App Store 记录不变） |
| v1.20.1 | 刘海遮挡检测：菜单栏图标被刘海或拥挤菜单栏静默吞掉时自动弹出管理窗口（LSUIElement 后台代理不再失联）；主窗口与弹窗显示警告横幅，引导退出部分菜单栏应用腾出空间；Finder 重新打开应用也会召唤主窗口 |
| v1.20.0 | UI 重设计 + 品牌命名分层：新增设计系统组件（AppIconView / AppTypeBadge / RowActionButton / StatChip）；主窗口分组列表 + 概览页 + 应用详情页（新增常驻开关与唤起提示）；弹窗按类型分组、行按钮悬停显现；聚合面板改 HUD 毛玻璃材质、图标块升级；紫/绿类型配色改为中性徽章；仓库 / 包 / 目录迁移 kebab-case（`status-bar`），App 显示名保持 StatusBar |
| v1.19.8 | 移除设置页无实际作用的「聚合/标准/禁用」三种运行模式（历史遗留的空选项），连同弹出页模式徽标一并清理 |
| v1.19.7 | 修复 ResidentBarManager 编译错误与遍历时改字典崩溃 |
| v1.19.6 | 后台代理化：`LSUIElement` 无程序坞图标，关任何窗口不退出，常驻图标持续保留（真正常驻）；菜单栏类应用点击无界面属 macOS 限制 |
| v1.19.5 | 状态栏常驻：勾选应用图标直接入住系统菜单栏（每应用一个常驻图标，左键唤起 / 右键管理），启动不再自动弹出浮动面板，解决桌面黑框干扰 |
| v1.19.4 | 常驻面板管理：+ 添加 / 悬停 × 移除 / 持久化 pinnedAppIDs |
| v1.19.3 | 修复聚合面板自动弹出 / 自动收起逻辑 |
| v1.19.0 | 使用体验修复：启动不再自动弹出聚合面板（仅响应运行期间新出现的菜单栏应用）；面板补标题栏计数与 × 关闭按钮、支持 Esc、固定深色外观、禁止误拖；主窗口补搜索框、行选中与右侧应用详情、操作按钮改为 hover 显隐；popover 底部补主窗口入口与面板开关（带状态） |
| v1.18.0 | 应用图标更换为滑块玻璃面板：按 1024 满幅 + 烘焙圆角重新生成，兼容 macOS 12+ 与 macOS 26/27 新图标网格；补深色外观；`tools/generate_app_icon.py` 可复现生成 |
| v1.17.0 | 发布链路修复：MAS `.pkg` 改用 3rd Party Mac Developer Installer 签名并导入 WWDR G3；描述文件 UUID 改用 grep；停止跟踪证书 / 描述文件等上传产物 |
| v1.16.0 | 品牌统一：StatusBar Pro → StatusBar；仓库与 Pages 从 EasyBar 迁至 StatusBar |
| v1.15.0 | 修复排序页自动写入导致「未排序」失效；区分 Normal/Disabled 模式；完善测试与构建验证 |
| v1.14.0 | 代码 review（P0×3 / P1×7 / P2×3）：聚合面板点击激活、Popover 双 toggle 竞态、hover 暂停自动隐藏、Force Quit 二次确认、`Bundle.main` 自排除、`openApplication` 迁移、Layout 常量收敛、单元测试 + CI；外观主题；多语言 |
| v1.13.0 | Status Bar app 跳转修复 |
| v1.12.0 | App 类型检测 + 移除 hide 功能 |
| v1.11.0 | 移除 hasStatusBar 自动检测 |
| v1.10.0 | accessory app 检测 + eye icon 手势修复 |
| v1.9.0 | HSplitView 布局 + stat card 联动 |
| v1.8.0 | UI 重新设计 + Sidebar 修复 |
| v1.7.0 | Quit/force-quit + App 状态检测 |
| v1.6.0 | 移除 AX 隐藏，纯 UI 聚合方案 |
| v1.5.0 | AX API 兼容性 + debug 工具 |
| v1.4.0 | AggregationPanel 可达 + iconSpacing |
| v1.3.0 | P0/P1 code review 修复 |
| v1.2.0 | Window + status bar 支持 |
| v1.1.0 | Phase 1-5 完整实现 |
