# 灵爪收纳 SmartPaw

**新电脑 / 新对话接手请先读 [HANDOFF.md](HANDOFF.md)。** 当前界面对齐进度保存在 `codex/figma-ui-handoff-20261021` 分支；包含代码、Figma 节点、截图、已确认设计和下一步。全量 UI 还原与全部功能验收尚未完成。

灵爪收纳是一款 iOS 收纳整理应用。拍摄或导入桌面照片后，手机在本地给出物品候选；用户核对、补录后生成整理方案，并记录每一步的完成情况。

本地识别用于减少录入工作，无法保证识别照片中的全部物品。识别为空时也可以手动添加物品，继续使用文字整理指引。

## 功能

- **拍照识别**：设备本地识别桌面物品，识别结果以标签形式标在照片上
- **AR 实时扫描**：提供实时标签通道；真机相机与 AR 验收尚未完成
- **方案生成**：根据识别结果生成分步整理方案，支持对话式微调
- **收纳引导**：按实际方案逐步完成，缺少定位的手动物品使用文字指引
- **空间管理**：多个空间各自维护整理前后的照片与进度
- **项目与徽章**：第三栏使用“我的计划”卡片设计，展示真实计划和排期；日历入口按用户要求移除。12 枚徽章中已有 2 项真实解锁规则，其余待实现
- **AI 设置**：可自行配置第三方 AI 服务，明确同意后才发送数据；旧社区入口已由项目替换

## 运行环境

| 项目 | 要求 |
| --- | --- |
| 开发机 | macOS |
| Xcode | 本地验证使用 16.4；提交 App Store 需 26 及以上及 iOS 26 SDK |
| 系统版本 | iOS 18 及以上 |
| 网络 | 非必需。识别与方案生成默认全部在本地完成 |
| 开发者账号 | 本地调试可使用免费 Apple ID；App Store 发行需付费 Apple Developer 资格 |

## 运行方式

```bash
git clone https://github.com/Qszjlzz/LingZhuaShouNa.git
cd LingZhuaShouNa
open SmartPaw.xcodeproj
```

Xcode 打开工程后，选择 iPhone 真机或模拟器，按 Cmd + R 运行。首次构建会编译 Core ML 模型，耗时几分钟。

若提示签名错误，在工程文件的 Signing & Capabilities 中选择自己的 Apple ID 即可。

## 怎么用

1. 拍照：在首页进入拍摄页，拍下需要整理的桌面
2. 看方案：识别完成后生成整理方案，可继续微调
3. 按引导整理：按真实方案逐步记录进度，全部完成后保存实际完成照

识别为空时可手动录入物品。识别候选需自行核对；当前全场景精度仍未通过仓库原有门槛。

## 常见问题

| 现象 | 处理方式 |
| --- | --- |
| 真机安装后无法打开 | 设置 → 通用 → VPN 与设备管理 → 信任描述文件 |
| 一周后应用无法打开 | 免费 Apple ID 签名有效期 7 天，重新安装即可 |
| 界面白屏 | 用 Xcode 重新构建，网页产物位于 Resources/FigmaMakeLatestWeb |
| 识别结果为空 | 应用只显示模型真实识别到的物品，光线过暗或物体过小可能漏检 |

## 目录结构

```
App/                     原生层：WebView 容器、视图模型、相机、钥匙串
Services/                识别链路、方案引擎、大模型兼容层、持久化
FigmaMakeLatest-v3/      界面源码，基于 React 与 Vite
Resources/Models/        Core ML 模型
Resources/FigmaMakeLatestWeb/  打包进应用的界面构建产物
SmartPawTests/           单元测试
docs/                    设计稿映射、识别基线、验收记录
```

修改界面的流程：安装 `FigmaMakeLatest-v3` 的依赖后，在仓库根目录执行 `scripts/build-bundled-web.sh`，同步完整网页产物，再用 Xcode 重新构建。

## App Store 提交状态

当前尚不可提交：开发者发行资格、模型授权、公开隐私政策和支持资料未准备，工作站也需升级到 Xcode 26/iOS 26 SDK。提交前还需真机相机与识别验收。详见 [提交准备](docs/app-store/README.md) 和 [识别验证](docs/app-store/recognition-validation.md)。
