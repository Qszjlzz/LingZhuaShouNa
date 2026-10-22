# 2026-10-23 真实生图供应商验证

本轮仅发起 **1 次真实图片编辑请求**，在 Mac 上通过 `beeapi.dev` 的 `gpt-image-2` 成功取得图片、解码并写入本地文件。没有重试，没有将生成图片加入识别评测集。随后用同一真实输出在模拟器中完成生产 `ImageGenerationManager` 的持久化与新 Manager 恢复验证（1/1 通过，见 `real-output-cache-20261023.md`）；没有完成手机直连、App 内预览或进程重启恢复验收。

## 输入与授权范围

- 沿用用户此前授权的第三方直连及一次受控真实生图验证，未追加批量或付费重试。
- 原图：`Resources/ExternalScanTests/external-cluttered-study-pexels.jpg`，项目既有 Debug 桌面照片；`docs/灵爪收纳-真实帧识别基线.md` 标注为真实学习桌图片，文件名标注 Pexels。仓库没有逐图原始 URL 或许可证证据，因此本记录不将其宣称为已完成发行素材许可核验。
- 原图 6720×4480、3,222,544 bytes；SHA-256 `8b4a85639f110fa7a440949dd21d7f34b4f486d07f22f64860fcebe146a23cd2`。
- 为接近当前原生拍照预处理，上传副本缩至 2048×1365、JPEG quality 88，重新编码不复制 EXIF，516,024 bytes；SHA-256 `e0d13ed7bbd68f215930ed139df2745e73970d1c21b81f47e444a0af2590ee5f`。
- 输入清单位于忽略目录 `outputs/image-api-smoke-20261023-controlled/input-provenance.json`。该样本不是新冻结的准确率 holdout。

## 真实结果

执行时间：2026-10-23 01:42:02 至 01:43:57（Asia/Shanghai）。使用 `scripts/check-image-api.py --direct --generate --timeout-seconds 300`，强制 HTTP/1.1，绕过本机 HTTP 代理。模型列表 GET 与图片编辑 POST 各 1 次；未重试编辑请求。

| 检查项 | 实际结果 |
| --- | --- |
| 模型列表 / 模型可见 | HTTP 200 / `gpt-image-2` 可见 |
| 真实编辑请求 | HTTP 200，112.67 秒 |
| 返回格式 | `b64_json`，本轮没有真实 HTTPS 图片 URL 下载 |
| 文件写入 | 成功，PNG，2,326,297 bytes |
| 完整图片解码 | Pillow `load()` 成功，RGB，1254×1254 |
| 输出 SHA-256 | `28653353145ceec354420008e731ea789ccbffffacb46fbe4f4134da89334aec` |

可复核文件均在 `outputs/image-api-smoke-20261023-controlled/`：

- `input-desk-2048.jpg`：本轮实际上传副本。
- `organized-desk.png`：真实供应商返回的图片字节。
- `summary.json`：脱敏状态码、耗时、输入/输出 hash、请求次数与 UTC 时间。
- `decoded-image-validation.json`：完整解码、实际尺寸与请求尺寸比较。

未保存或打印 API Key、私有配置、完整上游响应正文或带签名的下载 URL；供应商计费金额没有测量。

## 效果判断与证据边界

肉眼对照可见桌面变整洁，电脑、平板、手机、眼镜和部分书本/文具保留了可辨识对应关系，但不满足“原样保留所有物品”的严格要求：纸团消失，纸本/文具的数量或形态发生变化。输入为 3:2，输出变为方图；请求 `size=1024x1024`，实际文件为 1254×1254，说明该供应商本次未严格遵守请求尺寸。不能将这一次结果写成生图保真或物品完整保留验收通过。

本次 112.67 秒接近现有私有配置的 120 秒超时，且 Mac 直连成功不能推断 iPhone 网络耗时相同。300 秒仅用于本次 CLI 覆盖参数，未改动私有配置和 App 默认值。

可确认的是 **Mac → 真实供应商编辑 → base64 解码 → 本地文件落盘**，以及同一真实 PNG 在模拟器中经过生产 `ImageGenerationManager` 的 JPEG 重编码保存、新 Manager 同键恢复和可解码验证。改变空间/方案标识、原图字节或提示词的三项查找均未命中，专项测试于 2026-10-23 02:34:39 通过（1/1、0.641 秒）；完整证据和边界见 `real-output-cache-20261023.md`。这项验证未新增供应商请求。

以下仍未覆盖：真实 HTTPS URL 下载、iPhone 直连与上传同意 UI、App 被结束后的预览恢复、生产网页缓存恢复、真机文件保护、弱网/取消/重试稳定性、分区效果和多场景保真。URLProtocol 响应解析测试仍属于网络替身测试，不能替代这些实测；本次真实字节的生产 Manager 验证与之分别记账。

## 本轮脚本修正与检查

`scripts/check-image-api.py` 的 HTTPS 图片下载现在继承 `--direct`，避免编辑请求直连而 CDN 下载意外沿用代理；图片下载不携带 API Key。新增受限 30–300 秒的 CLI 超时覆盖，记录 `edit_request_count`、`response_mode` 与 UTC 时间；失败也写入脱敏 `summary.json`。

执行了 Python 语法编译检查，以及本地网络替身检查：base64 路径、HTTPS URL 路径（确认无代理 handler、无 Authorization、超时上限）、失败 summary 的落盘与凭证/正文脱敏均通过。它们与上述唯一真实请求分别记账，不能计作额外真实供应商成功或真机验证。未修改原生服务、网页资源或版本号。
