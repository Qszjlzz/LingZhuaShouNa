# 2026-10-23 真实生图结果的原生缓存验证

结论：已有真实供应商 PNG 通过生产 `ImageGenerationManager` 保存为可解码 JPEG，销毁首个管理器后，新建管理器在相同缓存键下能找回该文件；更换空间/方案标识、原图字节或提示词的三项查找均未命中。此次没有新增生图请求。

## 样本与执行

- 测试：`PhotoImageProcessingTests.testRealGeneratedPreviewCacheRestoresAfterManagerRecreation`，仅设置 `SMARTPAW_GENERATED_IMAGE_PATH` 时执行，否则跳过。
- 真实输出：`outputs/image-api-smoke-20261023-controlled/organized-desk.png`，2,326,297 bytes，1254×1254，SHA-256 `28653353145ceec354420008e731ea789ccbffffacb46fbe4f4134da89334aec`。测试校验该 hash，以免误用替代图片。
- 对应原图：同目录 `input-desk-2048.jpg`，SHA-256 `e0d13ed7bbd68f215930ed139df2745e73970d1c21b81f47e444a0af2590ee5f`；用于生产 fingerprint 的输入字节。提示词使用明确标记为本地缓存验证的固定文本。
- 环境：iPhone 16 Pro 模拟器，iOS 18.5，arm64，设备 ID `D4AFC2D2-6379-431E-AE17-F828DBB53484`；独立派生数据目录 `/tmp/smartpaw-real-cache-simulator-20261023`。
- 时间：2026-10-23 02:34:39（Asia/Shanghai）；实际单项 **1/1 通过，0 失败、0 跳过，0.641 秒**。`xcresulttool get test-results summary` 确认 `result=Passed`、`totalTestCount=1`。

## 生产接口与断言

测试使用独立 `UserDefaults(suiteName:)` 和临时 Documents 目录，结束后删除，仅调用生产 Manager 的 `fingerprintedCacheID`、`persistGeneratedImage`、`cachedPreview`，未调用 `generatePreview` 或供应商接口。

1. 校验真实 PNG 与原图 hash，并用 `UIImage` 解码输出，确认 1254×1254。
2. 将真实 PNG 交给 `persistGeneratedImage`；生产逻辑以 quality 0.88 重编码 JPEG。实际保存 **459,742 bytes**，JPEG 文件头及 `UIImage` 解码通过，尺寸仍为 1254×1254。重编码有损，因此不要求 JPEG hash 与原 PNG 相同。
3. 首个 Manager 离开作用域后，使用相同隔离目录新建 Manager；相同空间/方案 ID、原图字节和提示词恢复至完全相同路径，文件仍可解码。
4. 提示词改变、原图字节改为另一张有效图片（真实输出 PNG）、空间/方案 ID 改变，分别得到 `nil`。
5. 保存的图片作为 `real-provider-output-restored-from-production-cache` 附件保留在结果包中。

## 证据位置与边界

- 结果包：`/tmp/smartpaw-real-cache-validation-20261023.xcresult`。
- 原始测试日志：`/tmp/smartpaw-real-cache-test-20261023.log`，含 `SMARTPAW_REAL_GENERATED_CACHE` 的原图/结果 hash、JPEG 字节数、尺寸和恢复结果。
- 实际执行：`xcodebuild test-without-building -xctestrun /tmp/smartpaw-real-cache-simulator-20261023/Build/Products/SmartPaw_iphonesimulator18.5-arm64.xctestrun -destination 'platform=iOS Simulator,id=D4AFC2D2-6379-431E-AE17-F828DBB53484' -only-testing:SmartPawTests/PhotoImageProcessingTests/testRealGeneratedPreviewCacheRestoresAfterManagerRecreation -resultBundlePath /tmp/smartpaw-real-cache-validation-20261023.xcresult`；输入路径仅注入该独立 xctestrun。

这是**真实供应商字节在模拟器中经过生产 Manager 的持久化和对象重建验证**，并非文件层替身。它不证明 App 进程结束后的恢复、真机存储/文件保护行为、生产网页预览恢复或 iPhone 生图网络上传成功；也不验证供应商保真、其他场景或真实 HTTPS 下载。
