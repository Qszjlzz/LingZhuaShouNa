# 灵爪收纳 SmartPaw

对着乱掉的书桌拍一张照片，App 在本地识别出有哪些东西，然后给出一份能照着做的收纳方案，并跟踪你做到了第几步。

中国高校计算机大赛 · 移动应用创新赛 —— 赛区一等奖

## 它解决什么

整理类 App 的通病是让用户自己录入物品、自己想步骤，结果还没开始整理就先放弃了。SmartPaw 把这两步都交给机器：

- **不用录入**：拍照即可，识别全部跑在设备本地（Core ML），离线可用
- **不用自己想**：方案是分好步骤、带时间预估和工具清单的，勾选即完成

## 一次完整的整理流程

拍一张书桌照片，识别结果：

```
电脑设备  76%      杯子  59%
书本      42%      手机  39%
```

生成方案（本地规则引擎，3 步）：

```
1. 把书本竖放归位
2. 建立充电与设备区
3. 饮品容器清洗归位
```

如果配置了大模型，同一张照片会升级成这样（DeepSeek 实测输出）：

```
总述：用 60 分钟把书桌左侧改造成竖放区，右上角集中充电
工具：收纳盒、理线器、书立、抹布

1. 清空左侧桌面并分类（10 分钟）
2. 建立竖放区与手边工具区（25 分钟，最常用的书脊朝外）
3. 右上角集中充电（25 分钟，插头朝外，桌面中间留空）
```

两种方案都可用，没有网络或没配 Key 时自动回退到第二种。

## 功能

| 模块 | 说明 |
| --- | --- |
| 拍照识别 | 设备本地分割 + 分类，输出物品与置信度 |
| 方案生成 | 按时间预算、整理风格、目标生成分步方案，可勾选进度 |
| 空间管理 | 多个空间各自维护整理前/后对比照 |
| 物品分类 | 按类别分组管理，支持增删 |
| 社区 | 真实案例的点赞、收藏、关注、评论 |
| 整理日历 | 排期与完成状态 |
| 成就徽章 | 整理进度积累解锁 |
| AI 助手 | 对话式咨询，走同一个 LLM 接口 |

## 技术栈

| | |
| --- | --- |
| 语言 / 框架 | Swift、SwiftUI，iOS 16+ |
| UI | React + Vite（Figma Make 导出），由 WKWebView 承载 |
| 端侧模型 | YOLO11n-seg、EdgeSAM、MobileCLIP、DeepLabV3（Core ML，共 10 个） |
| 云端 | 任意 OpenAI 兼容接口（默认适配 DeepSeek Chat Completions） |
| 持久化 | JSON 快照 + Keychain（API Key 只存钥匙串） |

## 架构

UI 是网页，跑在 WKWebView 里；识别和方案生成是原生 Swift。两层通过 26 个 `nativeRequest` 命令双向通信。

```
React 页面 ──nativeRequest──▶ WKWebView 桥接 ──▶ AppViewModel
                                                   ├─ 识别服务（Core ML）
                                                   ├─ 方案引擎（本地规则 / 云端 LLM）
                                                   └─ 持久化（JSON + Keychain）
         ◀──window.__smartPawReceive───────────────┘
```

UI 做成网页而不是原生，是为了让设计稿改动不必重新编译原生层：Figma Make 导出后 `npm run build`，把产物覆盖到 `Resources/FigmaMakeLatestWeb/` 即可。

识别链路是多个模型互补：通用分割（YOLO11n-seg）出候选 → 可提示分割（EdgeSAM）抠边缘 → 图文对齐（MobileCLIP）确认类别。

## 运行

要求：Xcode 16.4+，iOS 16+，一台 Mac

```bash
git clone https://github.com/Qszjlzz/LingZhuaShouNa.git
cd LingZhuaShouNa
open SmartPaw.xcodeproj
```

Cmd+R 直接跑。首次构建会编译 Core ML 模型，需要几分钟。

可选：接入云端方案生成 —— App 内「我的 → AI 设置」填地址、模型名、Key，点「测试连接」验证。DeepSeek 填 `https://api.deepseek.com/chat/completions` + `deepseek-chat`。

## 能在安卓上用吗

不能，也没有安卓版。原因是核心能力全部依赖 iOS 专有框架：

| 用到的 | 作用 | 安卓替代 |
| --- | --- | --- |
| Core ML | 本地跑 10 个识别模型 | 无对应（需改 TFLite 重写推理层） |
| AVCapture | 拍摄取景、原地拍照 | CameraX，接口完全不同 |
| SwiftUI / Swift | 原生层与全部业务逻辑 | 需整体重写 |

所以安卓既装不了也模拟不了。想让安卓用户看到界面，只能用下面的「网页版演示」——它只有交互，不是真机效果。

## 怎么给别人装上 / 演示

先说清限制：**iOS App 只能跑在 iOS 上**。iOS 模拟器也只有 macOS 版，安卓虚拟机（Android Emulator）跑的是安卓 APK，装不了这个 App，没有例外。所以"安卓上装一个 iOS 模拟器"这条路不存在。

四条路：①②是演示给别人看，③是自己调试，④是真机交付。

**① 网页版演示（最省事，安卓也能开，但不是真机效果）**

把 React 界面打包成纯网页，任何浏览器都能打开：界面和操作流程与 App 一致，点击、切换、点赞收藏都正常；**识别/拍照用示例数据模拟**（浏览器跑不了本地模型）。适合快速看交互，**不适合当真机效果交差**。

**要真机效果，只有下面两条：真机录屏（视频展示）或 直接装到 iPhone（真机操作）。**

**② 真机录屏（要"真机效果"又不想装 App 给别人，选这个）**

iPhone 自带录屏：设置 → 控制中心 → 加「屏幕录制」→ 从右上角下拉点录制按钮，3 秒倒计时后开始操作 App，录完再点一次停止，视频存到相册。要点：录之前开「勿扰模式」、把电量设成 100%、录一整条完整流程（拍照 → 识别 → 出方案 → 勾选完成）。这是比赛提交演示视频最通用的做法。

**③ iOS 模拟器（自己调试用，不是真机）**

Xcode 自带，任选 iPhone 机型 Cmd+R 即可。限制：没有摄像头，拍摄页会自动降级成"从相册选图"，识别仍然可用。

**④ 装到别人的 iPhone（真机）**

> 免费 Apple ID：一台设备 7 天过期，一年最多注册 100 台。付费开发者账号（¥688/年）可走 TestFlight，10000 名外部测试员、90 天有效，不需要对方 UDID。

步骤：

1. 对方把 UDID 发你（设置 → 通用 → 关于本机 → 设备标识符；或连 Mac 在 Finder 里点序列号那一行复制）
2. Xcode → 登录你的 Apple ID → 把 UDID 加到 [开发者后台 Devices](https://developer.apple.com/account/resources/devices/list)
3. 本地：`Product → Archive` → `Distribute App` → **Ad Hoc**（选 `SmartPaw`、勾上那台设备）→ 导出 `.ipa`
4. 对方安装：把 ipa 发过去，用 **Apple Configurator 2**（Mac）或爱思助手（Windows）装上；装完首次打开要去 设置 → 通用 → VPN与设备管理 里信任一下描述文件

> 不想走 Xcode 的话，两台手机都装 TestFlight 更省事，但需要付费账号 + 一次审核（约 1 天）。

## 目录结构

```
├── App/                        # 原生层：WebView 壳、AppViewModel、相机、Keychain
├── Services/                   # 识别、方案生成、LLM 兼容层、持久化、示例数据
├── FigmaMakeLatest-v3/         # 网页 UI 源码（React + Vite）—— 唯一在维护的版本
├── MakePreview/                # Figma Make 设计稿基线（改 UI 前对照用，node_modules 指向 v3）
├── Resources/
│   ├── FigmaMakeLatestWeb/     # 打包进 App 的 UI 构建产物（由 v3/dist 覆盖同步）
│   └── Models/                 # Core ML 模型
├── SmartPawTests/              # 单元测试（识别管线、方案质量对比）
└── docs/                       # 设计稿映射、识别基线、验收记录
```

改 UI 的流程：改 `FigmaMakeLatest-v3/src` → `npm run build` → 把 `dist/assets` 和 `dist/index.html` 覆盖到 `Resources/FigmaMakeLatestWeb/`。

## 已知限制

- 通用分割模型对杂物间这类场景召回偏低（垃圾袋、纸箱等不在常见类别里），需要微调才有明显改善
- 拍摄用真实摄像头画面垫在 WebView 底下取景；模拟器无摄像头时自动降级为选图
- AR 实景摆放尚未实现
