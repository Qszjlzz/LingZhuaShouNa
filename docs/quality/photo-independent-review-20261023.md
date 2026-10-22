# 拍照链路独立审查：2026-10-23

结论：当前补丁约束了大图解码、共享模型并发和旧扫描回调写入的风险，但仍缺真实相机、连续拍摄与设备内存证据。**拍照 P0 保持未关闭。** 本轮是既有工程的只读代码审查，只新增本记录；没有运行 `xcodebuild`、启动设备测试、拍摄照片或修改网页。

## 审查范围与代码结论

审查基于 `codex/figma-ui-handoff-20261021` 的未提交工作区，不能将 Git commit 单独视为本次完整补丁版本。

| 范围 | 代码可确认的行为 | 仍需验证的边界 |
| --- | --- | --- |
| `CurrentFigmaMakeWebView.swift` 拍照队列 | `camera.capture` 先返回小预览，再按照片 ID 串行识别；识别与持久化成功后写入 `photoScanResults`，失败写入 `photoScanErrors`。 | 队列仍会持有等待处理的 UIImage；串行处理不等于内存峰值已有上限。 |
| `scan.await` 与网页提交 | 携带 `captureIDs` 时最多等待 300 秒，核对扫描代次、空间和取消状态；失败返回错误。网页桥接超时为 330 秒；主拍摄流程出错时停留在拍摄阶段，零识别成功时可继续并手动补录。 | 不带 `captureIDs` 的旧入口只等待队列任务，没有同样的 300 秒期限。本轮未把各入口全部跑通。 |
| 新批次、取消与切空间 | `scan.begin` 清空本批结果和错误并取消旧任务；`scan.cancel` 使旧代次失效。`AppViewModel` 在推理后检查扫描上下文与空间，取消时回滚未提交照片会话。等待相机照片返回后也核对代次和空间。 | 需要快速返回、重拍、切空间与慢识别组合的运行证据，确认旧结果不会进入新批次。 |
| 相机大图与方向 | 相机编码数据经 ImageIO 下采样，最长边不超过 2048，再交给识别；共享归一化按实际像素尺寸与方向绘制，并设置 renderer scale 为 1。 | 已有 7 项模拟器图像测试覆盖尺寸和方向，实际设备拍照仍需确认朝向、裁剪和预览。 |
| YOLO / MobileCLIP | 共享 YOLO、MobileCLIP 图像模型分别通过专用串行队列预测；YOLO 每个模型预测独立使用 autorelease pool，临时输出张量可在下一模型前释放；设备配置避开 GPU 路径。 | 模型仍常驻；YOLO 与 MobileCLIP 不共享同一队列。没有本轮真机内存、Jetsam 或温升测量，不能认定已证实原崩溃根因。 |
| WebContent 进程终止 | `webViewWebContentProcessDidTerminate` 调用 `stopCaptureWork()`，清理扫描/相机工作并重载内嵌网页；未提交会话回滚。 | 拍摄页面的照片列表与步骤状态没有恢复机制。进程终止后重新打开页面不等于恢复本批拍摄。 |

主要源码入口：`App/CurrentFigmaMakeWebView.swift`、`App/AppViewModel.swift`、`App/CameraEngine.swift`、`App/ImageDecoding.swift`、`Services/SmartPawServices.swift`、`Services/MobileCLIPRecognitionService.swift`、`FigmaMakeLatest-v3/src/app/components/ShootFlow.tsx`、`FigmaMakeLatest-v3/src/app/nativeBridge.ts`。

## 现有证据的使用边界

[图像管线回归记录](photo-pipeline-20261023.md)记录了 7/7 模拟器图像处理测试通过；这是尺寸、方向和输入处理证据，不是真实相机或整条业务流程通过证明。

并行构建代理报告 Build 8（1.0.0）已完成真机构建与签名，产物为 `/tmp/smartpaw-photo-device-build8-20261023/Build/Products/Debug-iphoneos/SmartPaw.app`；其定向测试被 `Unlock iPhone to Continue` 阻断，结果为 `TEST INTERRUPTED`、`passedTests=0`。结果包为 `/tmp/smartpaw-photo-device-build8-20261023.xcresult`。本轮未重新运行或独立解析该结果包，不将其记作真机测试通过，也不据此确认 Build 8 已安装。

## 下一次真机验收

1. 保持 iPhone 解锁，核对实际安装的 App build、补丁工作区版本及内嵌网页 hash；安装包与测试结果分开记录。
2. 从最新 App 实际相机完成“拍照 → 识别 → 提交 → 方案”，再连续拍摄至少 6 张；记录每张照片编号、最终列表与错误提示，确认无原生退出或 WebContent 重载。
3. 覆盖快速返回、重拍、切空间、慢识别后取消、前后台/锁屏恢复，以及权限拒绝后在设置中重新授权。保存失败与无识别结果应分别验收。
4. 保存对应时间的崩溃/Jetsam 与设备内存记录。没有异常日志不等于已测内存峰值；用 Instruments 或设备调试记录核对实际峰值与连续拍摄后的释放情况。
5. WebContent 中断需要单独设计可控验证入口，并先明确是否要求恢复本批拍摄。系统杀进程不能作为稳定自动化复现方式。

## UI 验收入口

仓库当前只有 `SmartPaw` 与 `SmartPawTests` target，没有发现独立 UITests/XCUITest target 或 `.xctestplan`。既有质量记录证明 iPhone 镜像曾可用于查看实际页面，但本轮没有再次验证镜像相机兼容性，也未确认 Xcode 设备屏幕入口的具体菜单。可通过可用的设备画面入口手动验收；这不能写成相机 UI 自动化已具备。
