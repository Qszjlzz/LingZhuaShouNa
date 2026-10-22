# 拍照图像管线回归：2026-10-23

> 下文是早期定向回归历史。后续 build11 真实 React 与六拍队列已通过；当前结论以 [最新验收记录](validation-results-20261023.md) 和 [设备摘要](device-camera-20261023.json) 为准，早期“尚无真机拍摄”不能覆盖后续结果。

本次在既有工程中补完拍照大图解码和方向处理，保留工作区已有的 YOLO 串行推理与 `.cpuAndNeuralEngine` 配置。这里记录的是图像处理和模型回归证据，不能据此关闭真机拍照 P0。

## 源码改动

- `App/CameraEngine.swift`：相机 JPEG/HEIF 数据通过 ImageIO 直接生成最长边不超过 2048 像素、方向已修正的图片，再交给 bridge；不再用 `UIImage(data:)` 保留整张原图。
- `App/ImageDecoding.swift`：解码时关闭原始图缓存，立即缓存缩略图；新增共享的识别归一化路径，先确定输出像素尺寸、再按方向绘制，明确 renderer `scale = 1` 与标准色彩范围。
- `Services/SmartPawServices.swift`：YOLO/Vision 归一化复用共享路径；每个 YOLO 模型预测使用独立 autorelease pool，及时释放大输出张量。
- `Services/MobileCLIPRecognitionService.swift`：语义图像归一化复用共享路径；一张照片的多个候选共享同一张归一化图；共享 MobileCLIP 图像模型通过专用串行队列预测，设备配置也避开 GPU 路径。
- `SmartPawTests/PhotoImageProcessingTests.swift`：新增 7 项定向测试。

## 通过的验证

Scheme：`SmartPaw`。模拟器：iPhone 16 / iOS 18.5，ID `DECE4A2E-103D-4BB6-9CA0-06F902AA8C7B`。

```sh
xcodebuild -project SmartPaw.xcodeproj -scheme SmartPaw \
  -destination 'platform=iOS Simulator,id=DECE4A2E-103D-4BB6-9CA0-06F902AA8C7B' \
  -derivedDataPath /tmp/smartpaw-photo-crash-sim-20261022 \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:SmartPawTests/PhotoImageProcessingTests test
```

结果：**7/7 通过，0 失败**。覆盖：4032×3024 的 12MP JPEG 直接解码、全部 8 种 EXIF 方向和镜像、3× 图片 scale、大图识别与语义归一化、裁剪坐标、小图不放大、256×256 语义输入和非法输入。用四角不同颜色核对旋转与镜像，避免只看输出尺寸。

结果包：`/tmp/smartpaw-photo-crash-sim-20261022/Logs/Test/Test-SmartPaw-2026.10.22_23-47-56-+0800.xcresult`。`xcresulttool get test-results summary` 确认 `result = Passed`、`passedTests = 7`。

修改过的 Swift 文件通过 `swiftc -frontend -parse`；`git diff --check` 通过。工程默认 Swift format lint 存在大量既有格式警告，未进行无关全文件格式重写。

## 真机尝试与明确边界

真机 ID：`00008130-001019A81109001C`。运行既有 `testRepeatedPhotoRecognitionOverlappingLiveFramesSurvives` 的设备定向回归时，源码已完成构建和签名，但在 2026-10-22 23:59:00（Asia/Shanghai）报告：`Unlock iPhone to Continue`，无法启动测试。等待后中止；最终结果为 `TEST INTERRUPTED`，没有真机测试断言通过证据。

结果包：`/Users/qszjlzz/Library/Developer/Xcode/DerivedData/SmartPaw-gyxmktjlqjxqongnsvtsvsroubfb/Logs/Test/Test-SmartPaw-2026.10.22_23-57-53-+0800.xcresult`。

这次设备测试产物的 `CFBundleVersion` 是 `1`；该测试构建不代表新发行版本已安装。没有真实拍摄、连续 6 张、后台/锁屏恢复、权限重授权或 WebContent 存活验收，也没有新增真机内存/Jetsam 证据。大图内存放大路径已被代码和像素尺寸断言约束，但不能将它写成此次 SIGABRT 的已证实根因。

设备解锁后仍需继续既有交接里的真机拍后完整流程；真机通过前，P0 保持未关闭。
