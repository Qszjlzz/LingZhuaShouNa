# 灵爪收纳 SmartPaw

对着乱掉的书桌拍一张照片，App 在本地识别出有哪些东西，然后给出一份能照着做的收纳方案，并跟踪你做到了第几步。

中国高校计算机大赛 · 移动应用创新赛 —— 赛区一等奖

![首页 - 空间地图](docs/screenshots/home.png)

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

要求：Xcode 16.4+，iOS 16+

```bash
git clone https://github.com/Qszjlzz/LingZhuaShouNa.git
cd LingZhuaShouNa
open SmartPaw.xcodeproj
```

Cmd+R 直接跑。首次构建会编译 Core ML 模型，需要几分钟。

可选：接入云端方案生成 —— App 内「我的 → AI 设置」填地址、模型名、Key，点「测试连接」验证。DeepSeek 填 `https://api.deepseek.com/chat/completions` + `deepseek-chat`。

## 目录结构

```
├── App/                        # 原生层：WebView 壳、AppViewModel、相机、Keychain
├── Services/                   # 识别、方案生成、LLM 兼容层、持久化、示例数据
├── FigmaMakeLatest/            # 网页 UI 源码（React + Vite）
├── Resources/
│   ├── FigmaMakeLatestWeb/     # 打包进 App 的 UI 构建产物
│   └── Models/                 # Core ML 模型
├── SmartPawTests/              # 单元测试（识别管线、方案质量对比）
└── Legacy/                     # 早期原生 SwiftUI 版本存档
```

## 已知限制

- 通用分割模型对杂物间这类场景召回偏低（垃圾袋、纸箱等不在常见类别里），需要微调才有明显改善
- 拍摄功能依赖摄像头，模拟器无摄像头时会自动降级为选图
- AR 实景摆放尚未实现
