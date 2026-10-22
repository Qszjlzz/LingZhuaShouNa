# 整体与照片区域效果图入口验收

2026-10-23：补齐生产 React 方案页的整体/局部效果图入口。局部使用用户明确选择的照片四等分矩形（左上、右上、左下、右下），不是自动识别的桌面/桌下语义分区，也不把计划步骤里的归位位置当成来源分区。原整理步骤与单个收纳区域逻辑保持原样。

方案页可分别生成整体与四个局部参考图；请求保留完整原图画幅，指定坐标范围，并要求范围外的物品与位置保持不变。原图/效果图按钮允许核对生成前后。原图从选中空间的生产照片接口读取，避免多张拍摄时网页第一张缩略图与原生实际生图来源不同。

generate 和 restore 使用同一完整请求（方案名称、目标、操作与局部范围）。旧代码自动恢复只传 planID，会使原生重建的提示词与生成时不同而错失缓存。现在每个范围有独立身份，切换会取消当前原生请求；迟到结果不覆盖新范围。生成失败后可重试；进入页面、切换范围和缓存恢复不会主动发起新的生成。

验证：

- `npm run build` 通过，最后构建产物为 `dist/assets/index-CrZRXXaK.js`。尚未由本子任务复制到原生 Resources；主线程合并全部前端改动后统一打包。
- `node --test tests/imagePreview.test.mjs tests/nativeBridge.test.mjs tests/cameraPreviewLifecycle.test.mjs tests/guideProgress.test.mjs tests/spaceLayout.test.mjs`：31/31 通过。
- `tests/image-preview-ui-smoke.mjs`：390×844 与 320×844 共 6 项通过，页面 errors=[]。验证用户主动生成、区域坐标请求、原图对照、切换取消与迟到响应、失败重试、独立缓存和 reload 恢复。两张截图已实际查看。
- [机器结果](results.json)、[390截图](390-left-region-restored.png)、[320截图](320-left-region-restored.png)。

浏览器使用合成 SVG 图和 native bridge 替身，没有付费供应商调用、手机拍摄或真实生成照片。此结果证明网页交互和请求行为，不证明供应商遵守区域边界、保留所有物品或达到识别准确率目标。后续需用 AI 场景在生产生图服务上实际输出整体与局部图并逐物检查，自动语义分区、iPhone 生产页面与进程终止后的原生缓存恢复仍需单独验收。
