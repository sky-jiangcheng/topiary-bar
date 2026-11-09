# Topiary App Store 清单

## 当前 App Store 兼容范围

- 仅使用公共 macOS API
- 通过 `NSWorkspace.shared.runningApplications` 列出运行中的应用
- 不请求屏幕录制、输入监控、文件访问、网络访问或自动化权限
- **不请求辅助功能（Accessibility）权限**：仅使用公共 API 列出运行中的应用
- 包含最小 App Sandbox 授权文件 `Sources/topiary-bar/Resources/topiary-bar.entitlements`；MAS 还需要的两个签名标识键（`com.apple.application-identifier` = `<Team ID>.<Bundle ID>`、`com.apple.developer.team-identifier`）**不写死在该文件里**，由 `script/mas-entitlements.sh` 在构建时从 `BUNDLE_ID` 与签名身份派生到 `dist/mas.entitlements`。缺这两个键会吃 altool 90886 警告、TestFlight 构建可能进不去；写成第三份字面量则会让 CI 的 `vars.BUNDLE_ID` 一改就与描述文件悄悄失配
- 包含隐私清单 `Sources/topiary-bar/Resources/PrivacyInfo.xcprivacy`（`release.sh` 自动拷入 bundle 并 `plutil -lint` 校验）；缺失会被 App Store Connect 拒收
- App 图标由 `tools/generate_app_icon.py` 从滑块玻璃面板源图生成（`python3 tools/generate_app_icon.py [SOURCE_IMAGE]`），产物写入 `Sources/topiary-bar/Resources/Assets.xcassets/AppIcon.appiconset`
- 发布流程不依赖 Xcode 工程：`script/release.sh` 直接编译 SPM 产物并组装 `.app`

## 提交前必要步骤

1. 安装完整 Xcode、同意许可并用 `xcode-select` 选择（`xcode-select -p` 必须指向 `Xcode.app`，否则 SwiftUI 宏插件缺失，构建会失败）
2. 本地跑通一次发布构建：`CHANNEL=mas SIGNING_IDENTITY="Apple Distribution: …" bash script/release.sh`。签名身份名必须带 `(TEAMID)` 后缀，否则脚本在**开始编译之前**就失败（`TEAM_ID=…` 可显式覆盖）；给了 `PROVISIONING_PROFILE` 时还会把派生出的 identifier 与描述文件交叉校验，覆盖不一致同样硬失败
3. 在 Apple Developer 后台确认 / 创建 `com.jiangcheng.MacStatusApp` 的 App ID
4. 创建并下载 Mac App Store 类型的 provisioning profile
5. 确认 App Sandbox 由 `Sources/topiary-bar/Resources/topiary-bar.entitlements` 启用（MAS 渠道的 `-D MAC_APP_STORE` 会编译期移除退出功能）
6. 核对 `script/release.sh` 中内嵌的 `Info.plist`：Bundle ID、版本号（`APP_VERSION` / `BUILD_NUMBER`）、`LSMinimumSystemVersion`、分类
7. 隐私营养标签：**不收集任何数据**。隐私清单只申报 `NSPrivacyAccessedAPICategoryUserDefaults` / `CA92.1`（应用自身设置），与标签口径一致
8. 重新截取 App Store 截图。`AppStoreScreenshots/` 里的文件仍是改版前的旧品牌命名（`macstatus-*`），与当前 UI 不符
9. 上传：走 CI（`.github/workflows/release.yml`，推送 `v*` 标签）。两个发布 job 都绑定 `release` environment，需在 Repo → Settings → Environments 配置 required reviewers 与 secrets
10. 手动上传统一走 `bash script/asc-upload.sh dist/Topiary.pkg`（需要 `API_KEY_ID` / `API_ISSUER_ID`）。
    口径纠正（此前这条写的是"优先 iTMSTransporter，altool 仅作回退"，与实测不符）：
    `xcrun --find iTMSTransporter` 命中的是 Xcode 里的**提示桩**，本机与 runner 上都不存在真正的
    Transporter，因此它**永远不会上传任何东西**——实测 `-m upload` 打印"iTMSTransporter is now part of
    Transporter / 去 Mac App Store 安装"并**退出 1**，同一个桩 `-version` 却**退出 0**；GitHub runner 上
    它改抛 `-10814`（LaunchServices 找不到 Transporter）。旧写法靠"非 0 即回退 altool"（`09ce8ef`）确实
    能发布成功，所以这里**不是**在修一个现实的静默失败，而是：① 不再每次都执行一个注定失败的桩、
    只在 `Transporter.app` 真实存在时才用 iTMSTransporter；② 成功判据从"退出码 0"改为**上传器自己
    的输出证据**（实测措辞 `No errors uploading` / `UPLOAD SUCCEEDED` / `Delivery UUID:`），因为桩在
    `-version` 上已经证明"退出码"对这类二进制不可信；③ 非 0 退出不再被静默改道，认证类失败会直接
    让 job 失败，而不是伪装成"另一个上传器报的错"。

## 构建与打包（唯一流程）

| 渠道 | 命令 | Bundle ID | 沙盒 | 产物 |
|------|------|-----------|------|------|
| Mac App Store | `CHANNEL=mas bash script/release.sh` | `com.jiangcheng.MacStatusApp` | 开 | `dist/Topiary.pkg` → altool |
| 官网自分发 | `CHANNEL=devid bash script/release.sh` | `com.jiangcheng.EasyBar` | 关 | `dist/Topiary.app` → DMG → 公证 → GitHub Release Assets |

必需环境变量：`SIGNING_IDENTITY`（mas：`Apple Distribution: …`；devid：`Developer ID Application: …`），其余可选变量见 `script/release.sh` 头部注释。mas 渠道另有两个可选项：`TEAM_ID`（默认从签名身份名解析 10 位 Team ID）与 `PROVISIONING_PROFILE`（描述文件路径，用于交叉校验签名标识并内嵌进 bundle）。

本地开发用 `script/build_and_run.sh`，它采用 devid 渠道的 Bundle ID 与 entitlements（沙盒关闭）。

## 重要约束

全局快捷键使用 Carbon `RegisterEventHotKey`（`Control + Option + M` 唤起主窗口）：事件由系统直接投递给本进程，无需辅助功能权限，沙盒下可用。菜单栏图标右键菜单提供 `Control + Option + M`（打开主窗口）、`Command ,`（打开设置）和 `Command Q`（退出）；弹窗底栏同样提供 设置 / 打开主窗口 / 退出 三个入口。

## 已知限制

- Status Bar 应用无法通过 `NSRunningApplication.activate()` 激活（macOS 安全限制），本应用对 accessory 应用使用 `NSWorkspace.openApplication(at:configuration:)` 唤起
- 部分 accessory app（如 Macs Fan Control）无法被其他 app 激活
- App 类型检测基于 `activationPolicy`，无法读取真实的状态栏图标归属
- 应用不会隐藏系统菜单栏图标（AX 隐藏方案已于 v1.6.0 移除）；需要该能力请搭配 Hidden Bar / Ice 等专用工具
- 暗色 App 图标变体（`Assets.xcassets/AppIcon.appiconset/dark/`）只在 Xcode 资产目录（`Assets.car`）流程下生效；`script/release.sh` 用 `iconutil` 生成 `.icns`，该格式只包含浅色图标
- MAS 沙盒下 `NSRunningApplication.terminate()` 被系统拦截，因此 mas 渠道用 `-D MAC_APP_STORE` 编译期剔除退出功能
- 深色图标变体只走 Xcode 资产目录流程；`release.sh` 用 `iconutil` 生成的 `.icns` 仅含浅色图标

