# 重拍与重新点亮路由检查（2026-10-21）

本次范围为跨页面路由和真实保存逻辑，未据此宣称所有 Figma 画板或所有 App 功能已完成验收。

交接更新（2026-10-21）：下方 `index-Cd4O_xLE.js` 及“未复制”是子任务交付时状态。主任务随后统一打包、构建、安装；目前内嵌 JS 为 `index-Bm7H3tNW.js`，交接时与 dist 字节一致。普通整理主线有有限手动验证，compare/same/new 三入口、重新点亮完成照重拍/退出的最终完整 UI 验收仍未完成。详见 [HANDOFF.md](../../HANDOFF.md)，不能将资源已复制扩写成全部重拍通过。

## 修复

- App 现在接收空间页传出的 compare/same/new；compare 进入对应空间的重新点亮，same 进入拍摄后恢复原方案，new 进入生成新方案的拍摄主线。
- 空间页重拍会选择当前碎片或当前原生空间，保留真实 UUID 和名称。
- 新增原生 plan.reuse：校验空间和方案身份，为步骤和方案生成新 UUID，重置执行进度，保留已归档方案；写入失败恢复空间和执行区域。
- 重新点亮等待本批识别结果，不再以 8 秒超时读取旧物品；分区后实际生成、持久化方案，经过现有 AR 引导完成步骤后进入完成照。
- 重新点亮完成照使用原生暂存预览，点击“完成整理”才归档；重新拍摄会丢弃暂存并恢复预览，退出会清除暂存。保存时再次校验空间与方案身份。
- 重新点亮返回空间后刷新原生状态。

## 验证结果

- FigmaMakeLatest-v3 npm run build 通过，最终本地 dist JS 为 index-Cd4O_xLE.js。此次未将 dist 复制进 Resources/FigmaMakeLatestWeb，应由集成人员使用 scripts/build-bundled-web.sh 统一打包。
- SmartPaw scheme、iPhone 16 / iOS 18.5（DECE4A2E-103D-4BB6-9CA0-06F902AA8C7B）的 xcodebuild test：2 项通过、0 失败。测试覆盖恢复历史方案的独立身份/进度/持久化、非法身份拒绝，以及写入失败回滚。日志 /tmp/smartpaw-route-audit.log；结果 /tmp/smartpaw-route-audit/Logs/Test/Test-SmartPaw-2026.10.21_00-49-56-+0800.xcresult。
- 完成照桥接最终修改后的原生 xcodebuild build 通过；日志 /tmp/smartpaw-route-audit-build.log。
- git diff --check 通过。
- 通过 Babel AST 比较 Git HEAD 和当前 JSX motion 元素的 initial/animate/exit/transition/whileTap/whileHover/layout/layoutId：ShootFlow 54 个元素、SpatialScreen 23 个元素，属性序列完全一致。此结果证明这些声明未被改动，不等价于真机动画视觉验收。

## 待集成验证

- 统一打包 Web 资源、安装最终 App 后，实际点击 compare/same/new 三入口，并用相册或真机完成拍摄、方案执行、完成照确认、重拍、退出。
- 本次未执行相机真机验证，也未作逐画板截图对比；测试只覆盖新增原生方案恢复逻辑。
- 普通拍摄主线当前仍面向已选中的空间；创建新空间的产品流程需另行完整验收。
