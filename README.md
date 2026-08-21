# 灵爪收纳

灵爪收纳是一款面向个人空间整理的 iOS 原型，围绕以下流程工作：

`空间采集 -> 物品识别 -> 用户确认 -> 方案生成 -> 分区执行 -> 完成记录`

## 技术栈

- iOS / Swift / SwiftUI
- AVFoundation、Vision、ARKit、RoomPlan
- Core ML：YOLO 实例分割、DeepLabV3、MobileCLIP、EdgeSAM 相关资源
- 本地规则引擎生成整理方案，可选兼容 Responses API 的云端增强

## 打开工程

使用 Xcode 打开：

`SmartPaw.xcodeproj`

选择 `SmartPaw` Scheme 和 iPhone 模拟器或真实 iPhone 运行。真实相机、ARKit 和 RoomPlan 功能需要支持的真机及相机权限；模拟器主要用于界面、真实照片识别和流程演示。

## 构建

```bash
xcodebuild \
  -project SmartPaw.xcodeproj \
  -scheme SmartPaw \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build
```

## 目录

- `App/`：应用入口、依赖和数据生命周期
- `Features/`：空间、采集、分类、规划、执行、社区和个人中心
- `Models/`：业务模型和识别结果
- `Services/`：识别、分割、规划、存储和凭据服务
- `Resources/`：Core ML 模型、测试素材和 Asset Catalog
- `SmartPawTests/`：单元测试和识别评测
- `docs/`：开发过程、验收基线和复盘材料
- `HANDOFF.md`：当前开发交接、历史判断和下一步优先级

## 当前边界

项目是可演示原型，不应把有限真实图片评测结果外推为通用识别准确率。模拟器不能证明真机 ARKit/RoomPlan 的空间稳定性、延迟或发热。没有配置 API Key 时，App 使用本地规则引擎，不依赖云端服务。

开始继续开发前，请先阅读 [HANDOFF.md](HANDOFF.md)。
