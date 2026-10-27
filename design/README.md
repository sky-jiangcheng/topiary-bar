# design/ — 设计与决策留档

这个目录放**过程**，不放产物：产物在 `Sources/topiary-bar/Resources/Assets.xcassets/`
和 `docs/assets/` 里，这里记录的是"为什么长成这样"和"哪些路被否掉了"。

```
design/
├── icon/
│   ├── README.md              图标决策日志（v1 照片 → v2 → v3 → v4）+ 复现命令
│   ├── source/                每一个候选的 1024 母版（含未入选者、含小尺寸简化档）
│   ├── contact-sheet.png      候选横向对比（light/dark × 128/64/32/16）
│   └── review-small-sizes.png 像素级评审：16/32 原尺寸 + 6× 放大 + 白/黑底剪影
└── reviews/
    └── 2026-10-27-ui-critique.md   本轮 UI 重做的输入（外部评审报告，原样保留）
```

## 图标

见 [`icon/README.md`](icon/README.md)。一句话：SSOT 是 `tools/generate_app_icon.py`，
PNG 全是派生物；改图标改代码，然后 `--measure` / `--review` 复核，不要手 P 图。

## 界面与代码：审查报告逐条处置

输入是 [`reviews/2026-10-27-ui-critique.md`](reviews/2026-10-27-ui-critique.md)。
它按 P0→P3 排了优先级，下面是**对照当前工作区**的处置结果——包括没做的部分。

| 报告条目 | 处置 | 落点 |
|---|---|---|
| §2.1 Header 图标 16→20 | 已做 | `PopoverView.headerSection` |
| §2.1 内存条太细（约 3pt） | 已做，改 4pt | `PopoverView.memorySection` |
| §2.1 footer 三按钮同一行、视觉重量混乱 | 已做，主操作独占一行，齿轮/退出降为次级行 | `PopoverView.footerSection` |
| §2.1 遮挡横幅对比度不足 | 已做，`warning.opacity(0.15)` + 1pt `0.4` 描边 | `PopoverView.occlusionBanner` |
| §2.1 搜索框上下 padding 叠加 | **复核后不改**（见下方"复核后不改的"） | — |
| §2.2 行内按钮常驻、Quit 太激进 | 已做，hover 才浮现动作 | `PopoverView.IconRow` |
| §2.2 Quit 无二次确认 | 已做，`confirmationDialog`，五语（en/zh/ja/de/es）文案齐 | `IconRow` + `Localization.quitConfirmTitle/Message` |
| §2.3 弹窗行与侧栏行设计语言割裂 | 已做，抽出 `AppRowContent` 共享数据层，两处各自包布局 | `Theme.swift` |
| §2.4 StatChip 的 iOS 风 Capsule | 已做，改 macOS 方卡 | `Theme.swift.StatChip` |
| §2.4 品牌标改左上角小徽标 | **部分**：缩到 32pt 并降权，但概览页仍是居中构图 | `ContentView.OverviewView` |
| §2.4 提示文字缺锚点 | 已做，并入 StatChip 区作副标题 | 同上 |
| §2.5 图标选择器标题/说明重复渲染 | 已做，组件只留网格，文案归 `SettingsView` 的 Section | `AggregationIconSelector` |
| §2.6 缺 Spacing token | 已做 | `Theme.Spacing` |
| §2.6 缺颜色语义 token | 已做 | `Theme.Color`（含本轮新增的 `brand`） |
| §2.6 缺字体 token | **未做** | 见"推迟的" |
| §3.2 两处搜索不同步应说明是决策 | 已做，写进官网"已知限制" | `docs/index.html` |
| §3.3 热键录制器手绘 `draw()` | **未做** | 见"推迟的" |
| §3.4 常驻区宽度硬编码 320 | 已做，改 `maxWidth: 360` | `ContentView` |
| §3.6 Quit 用红色提示危险 | **改法不同**：用 `Theme.Color.warning`（橙）而非红 | `footerSection` |
| §3.7 图标格子固定 3 列 | 已做，`.adaptive(minimum: 100)` | `AggregationIconSelector` |
| §4.3 过滤逻辑两处重复 | 已做，下沉 `MenuBarMonitor.matching` + 数组扩展 | `MenuBarMonitor.swift` |
| §4.4 同一数组遍历三次 | 已做，`countsByType` 单遍 | 同上 |
| §5 P3 官网：Hero / 截图 / CTA / 卡片描边 / footer | 已做（截图用 CSS 骨架窗口，不放假数据截图） | `docs/index.html` + `site.css` |

### 复核后不改的

**§2.1 搜索框"两层 vertical padding 叠加"**：报告的算法把两种不同用途的间距当成了
一层——内层 `.padding(.vertical, sm)` 是输入框**自身**的文字内边距（在背景之内），
外层是控件与邻居之间的**节奏**（在背景之外）。去掉任一层都会让搜索框要么贴字、
要么和 header 挤在一起。现状是有意为之。

**§3.6 退出按钮用橙不用红**：这个 app 里危险色只有一个——`Theme.Color.warning` 橙，
遮挡横幅、高内存占比、退出、强制退出都用它。再引入一个红色就会变成"两种危险色"，
读者要重新猜它们的区别。报告要的是"危险操作要显出危险"，这一点橙已经满足。

### 推迟的

**§2.6 字体 token**：`AppRowContent` 已经把两处行文字的字号收进一个入口，剩下的
散落 `.caption` / `.callout` 大多是语义正确的默认值。等真的出现"同一层级三种字号"
的回归时再收，比现在凭空造一套 `Theme.Font` 更不容易腐化。

**§3.3 热键录制器改 `NSTextField` 子类**：收益是视觉更接近系统控件，代价是要重做
first-responder 与按键拦截逻辑——`HotKeyRecorderView` 从 `HotKeyRecorder.swift:53`
起共约 76 行，`draw()` 只占其中 25 行左右，剩下的是事件处理，改宿主控件等于把这
些全部重验一遍。它不影响可读性或操作安全，本轮不碰。

## 颜色预算（三处同源，一处校验）

品牌绿只有两个值，图标、App、官网共用，由
`python3 tools/generate_app_icon.py --check-brand` 钉住，任一处漂移即失败：

| 用途 | 浅色 | 深色 | 实测对比度 |
|---|---|---|---|
| 品牌绿（图标旋钮 / `Theme.Color.brand` / `--brand`） | `#2E7D52` | `#7CBE96` | 5.03:1 on `#ffffff`；7.83:1 on `#1c1c1e` |
| 系统蓝（控件、焦点环、链接） | `#007AFF` / `#0A84FF` | 同 | 5.5:1 on white；4.6:1 on dark |
| 危险橙（遮挡、高内存、退出、强退） | `Color.orange` | 同 | — |

规则：**绿不是控件色**。绿色只出现在产品描述自己（图标、内存读数）的地方；
按钮、选中态、焦点环一律走系统 accent，避免和用户的系统强调色打架，也避免
品牌色被用成状态色。
