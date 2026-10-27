# 图标决策日志

**SSOT 是这个目录之外的那个脚本**：`tools/generate_app_icon.py`。
`source/` 里的 1024 母版、资产目录里的 PNG、`docs/assets/icon-256*.png`、以及
两张评审图，全部是它的派生物。**改图标 = 改代码 + 重跑**，不要手改 PNG——
手改的结果是下一次重跑静默覆盖，而没人知道图上那处改动原本是为了什么。

```bash
# 本机系统 python 没有 Pillow，用 uv 临时带一份（CI 里是 pip install pillow）
uv run --with pillow python tools/generate_app_icon.py                 # 画当前版本 + 写资产目录 + 刷官网 256
uv run --with pillow python tools/generate_app_icon.py --variant v3a   # 画任意历史候选（v2*/v3*/v4*）
uv run --with pillow python tools/generate_app_icon.py --sheet         # 候选横向对比图
uv run --with pillow python tools/generate_app_icon.py --review        # 小尺寸像素级 + 剪影评审图
uv run --with pillow python tools/generate_app_icon.py --measure       # 可读性/剪影量化数值
uv run --with pillow python tools/generate_app_icon.py --verify-assets # 资产目录是否仍等于代码输出
uv run --with pillow python tools/generate_app_icon.py --check-brand   # 品牌绿三处同源校验
```

后两条已经挂在 `.github/workflows/test.yml` 的 unit-tests job 上（约 13 秒）：
品牌色漂移、或者有人手改了资产目录里的 PNG，CI 直接红。

改完 artwork 必须同时把 `docs/*.html` 里的 `?v=` 缓存戳 +1（当前 `?v=4`）——
GitHub Pages 上残留的旧图标会被当成"你根本没改"。

## 识别常量（四轮没动过）

* 满幅画布，圆角半径 = 0.2257 × 边长（v1 就用的 macOS 26 "Tahoe" 网格，
  在 macOS 12–15 上也是这个渲染结果）。
* 两条竖直导轨，中心线在 38.5% / 61.5%。
* **左旋钮在上、右旋钮在下**——这条对角线就是这个标本身。
* 一颗品牌绿锚在左旋钮（值锚点）上，其余保持中性。

## 版本史

### v1（v1.18 – v1.26.x）照片

一张毛玻璃滑块面板的照片，按量测出的框裁切、遮成 squircle。两个硬伤：
深色变体是**朴素 RGB 反相**（等于把照片负片当图标）；16–32px 对比不够。
原片存在一次性上传目录里，**已经丢了**——这正是后来把 SSOT 改成代码的直接原因。

### v2（v1.27）程序化重绘

身份要素保留（玻璃面板、两导轨、左高右低、26 网格圆角），改成代码画。
`v2a-crisp` 入选，`v2b-studio` 备选，`v2c-bold` 否决（1024 上太厚重）。
事后发现 v2 的 `blur` 参数被当成"边长的小数"解释，比应有的量级大约一个数量级，
把阴影和高光全糊掉了——这是 v3 的修正项之一。

### v3 品牌色 + 尺寸分层

v2a 在 Dock 里实地看，两个问题是真的：**(a)** 完全无色，混在一排系统应用里
就是"通用灰壳子"，零品牌回忆；**(b)** 16–32px 上浅色导轨几乎消失。
v3 的答案：左旋钮一颗克制的 topiary 绿；小尺寸改从**加粗档**母版画；玻璃加内折射环。
候选 `v3a-accent`（入选）/ `v3b-graphite`（无色对照）/ `v3c-verdant`（绿玻璃，
品牌最响但偏离中性 macOS 质感，未入选）。

### v4（当前）小尺寸独立成档 + 剪影

v3a 落地后仍然有两件事不对，v4 就是冲它们去的：

**(a) 小尺寸档只是"同一张画加粗"。** 16px 实测：浅色档导轨糊成一团，
白色右旋钮直接融进白色面板。一张靠渐变、光泽、高光、内折射堆出来的画，
加粗救不回来——到 16px 还活着的只有几何。所以 v4 给 ≤32px 画了一张
**独立的简化母版**（`draw_small_master`）：平涂、实心暗凹槽、一条亮导轨、
一颗饱和度更高的绿旋钮、硬边，模糊参数为零。身份（两凹槽 + 那条对角线）
完全保留，砍掉的只是 16 像素根本承载不了的明暗词汇。

**(b) 这个标没有剪影。** 白桌面、访达、App Store 白页面上，面板底色 (216,220,227)
加 95 alpha 的外圈让 squircle 直接化进页面里。v4 压暗面板底部、加重外圈暗边
（深色档反过来提亮**上缘受光边**，因为黑 Dock 上要靠亮边分离），
并把右旋钮从纯白改成浅灰面 + 深描边。

关键一点：这些修正以 `REFINES` / `SMALL_PALETTE` **覆盖**的形式存在，
没有直接改 `PALETTES`——v2/v3 的候选至今仍能按当初评审时的样子重绘，
记录才可证伪。

`v4b-plain` 是**对照组**：同样的调色修正，但小尺寸仍走 v3 的加粗档。
它存在的意义就是回答"变清楚到底是简化档买来的，还是调色买来的"。

### v4.1（当前）真机验证改掉了 v4 的两处错

v4 的全部结论都建立在**合成评审图**上——把原始 PNG 直接贴到白/黑底。真机一跑，两件事是错的：

**(a) 交付形状搞反了。** macOS 26+ 读 `CFBundleIconName` → `Assets.car`，并且**由系统自己套
图标形状**；我们喂的是自带 squircle + 透明外角的图，于是被**二次裁切**：16px 真屏上缩成
一个近圆、内缩在系统底板里。喂**满幅方图**才对。
而 macOS 14/15 读 `CFBundleIconFile` → `.icns`，**不套形状**，那份必须自带圆角。
所以现在是**一份代码出两套形状**，都入库、都被 `--verify-assets` 钉住：

```
Sources/.../Assets.xcassets/AppIcon.appiconset   满幅  -> actool   -> Assets.car  (macOS 26+)
Sources/.../Resources/AppIcon.iconset            预裁  -> iconutil -> AppIcon.icns (macOS 14/15)
```

外部有独立同型报告：`water-rs/cli` issue #2「macOS asset-catalog app icons render
double-inset」，修法同为"mac idiom 槽位按满幅出图"。

**(b) 为"剪影"加重的暗边，在真屏 16px 上读成一圈黑框。** `--measure` 的 `edge` 指标把它
奖励成了"更好"，因为该指标只问"对底色有没有台阶"，不问"这个台阶看起来像不像描边"。
v4.1 把浅色档的 `rim_dark_alpha` 从 140 收到 112、面板底色从 (196,201,211) 抬回
(205,210,219)，小尺寸档描边 alpha 205→150、宽度 0.016→0.012。右旋钮的浅灰面 + 深描边保留，
那个是真收益。

**(c) 深色变体不是"没接上"，是根本编译不出来。** `AppIcon.appiconset/dark/` 那 10 张图
actool 一直报 `does not exist` + `has 10 unassigned children`——appiconset 不接受嵌套目录；
改成扁平命名后仍报 unassigned；再试单尺寸 `universal` 写法也一样。结论：**mac idiom 的
app icon 不支持 `appearances` 深色声明**，真正的深色 app icon 要走 Icon Composer 的分层
`.icon` 格式（Xcode 自带，但只有 GUI，没有命令行入口）。那 10 张深色图已从资产目录移除，
母版仍留在 `source/` 作设计记录。`--verify-assets` 现在会**主动拒绝** `appiconset/dark/` 复现。

顺带修掉一个开发链缺陷：`script/build_and_run.sh` 此前**完全不带图标**（无 `CFBundleIconFile`、
不生成 `.icns`、不跑 actool），所以日常开发包根本没法看图标；现在两个脚本走同一套双轨。

**方法教训**：第一版真机探针（合成绘制）连外观解析都不稳，给出的结论与真屏相反，已在归档里
标为"仅作方法记录，不要引用结论"。图标这类东西，判据必须是**真屏像素**。

## 实测数据

`--measure` 的三个口径（都是 WCAG 相对亮度比，可复算）：
`mark` = 左凹槽那条带上离面板最远的极值 vs 面板；`detail` = 中线水平亮度
台阶均值 ×100；`edge` = 上/下缘 vs 底色（浅图标对白桌面、深图标对黑 Dock）
两者取强。**底色是合成时真正会遇到的颜色，不是自选的**。

| 变体 | 档 | 尺寸 | mark | detail | edge |
|---|---|---|---|---|---|
| v3a-accent（上一版） | light | 16 | 1.41 | 6.01 | 1.38 |
| **v4a-refined（本版）** | light | 16 | **1.57** | **11.97** | **1.58** |
| v4b-plain（对照） | light | 16 | 1.39 | 5.47 | 1.50 |
| v3a-accent | light | 32 | 1.64 | 6.30 | 1.36 |
| **v4a-refined** | light | 32 | **3.36** | **20.44** | **1.58** |
| v4b-plain | light | 32 | 1.58 | 6.06 | 1.50 |
| v3a-accent | dark | 16 | 6.39 | 12.03 | 2.13 |
| **v4a-refined** | dark | 16 | **6.62** | **12.58** | **2.23** |
| v4b-plain | dark | 16 | 6.68 | 12.15 | 2.13 |
| v3a-accent | dark | 32 | 6.28 | 7.57 | 2.19 |
| **v4a-refined** | dark | 32 | **13.78** | **13.85** | **2.30** |
| v4b-plain | dark | 32 | 6.62 | 7.59 | 2.16 |

读法：

* **简化档是主要收益**。浅色 32px 的 detail 从 6.30 → 20.44，mark 从 1.64 → 3.36；
  同一档位的对照组 v4b 只有 6.06 / 1.58。也就是说"只调色"买不来可读性，
  是"换一张画"买来的。
* **调色修正买到的是剪影，不是清晰**。v4b 的 edge（1.50 / 1.50）相对 v3a（1.38 / 1.36）
  的提升与 v4a 同源，这部分归功于 `REFINES`。
* **v4.1 的回退是看得见的**：浅色 edge 从 v4.0 的 1.79 / 1.83 降到 1.58 / 1.58——
  降下去的那部分正是真屏上读成黑框的过重描边，而 v3a 只有 1.38，仍留有净增益。
  `mark` 与 `detail` 基本没动（1.57 / 11.97 vs 1.50 / 12.77），说明回退没有牺牲小尺寸可读性。
* **深色 16px 是打平**（6.62 vs 6.39，12.58 vs 12.03）——深色本来就没有白底融字问题。
  这一档没有变差，仅此而已。

## 已知不足（下一轮该打的）

1. **小尺寸档仍是 1024 母版降采样**。要在 16px 上画出真正 1px 宽的描边，
   母版得按目标像素尺寸原生绘制并做像素对齐——现在旋钮描边换算到 16px
   只有约 0.1px，靠抗锯齿糊出来。
2. **macOS 14/15 那一轨只做了约定推定，没有实测**。本机是 macOS 27，装不了 14/15；
   `.icns` 自带圆角是 pre-Tahoe 的通行做法，但"14/15 上满幅图会不会也被套形状"
   这件事只有真机或 CI 矩阵能证。
3. **深色 app icon 仍未实现**，只是不再假装它快好了。要做得引入 Icon Composer 的
   `.icon` 分层格式（GUI 工具，无 CLI），那意味着程序化 SSOT 的代码生成方式要重做——
   是一次独立的决策，不是顺手改。
4. **`--measure` 的 `edge` 指标有已知盲区**（见上文 (b)：它奖励了过重的描边）。
    保留它是因为它对"完全没有剪影"仍然敏感，但**不要单看它下结论**，
    真屏截图才是终判。
