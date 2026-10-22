# 分类与空间地图浏览器回归

2026-10-23 02:16（Asia/Shanghai）使用整理后的便携脚本复跑成功。Chromium桌面浏览器，Vite当前源码，原生桥接使用本地替身。`results.json` 记录30项检查/几何观测，`errors=[]`。这是网页交互证据，不是iPhone实机或云端存储证据。

390×844与320×844：空间轻点详情、编辑取消/保存、刷新持久化、拖动不误开详情；分类搜索/无匹配反馈、分组新增与移除、移除含物品组时保留并移入未分组、物品增删、返回均通过。另验证390→320缩窄的边界归一化与长按进入/退出编辑。

修复：BooksCategoryScreen弹层原先与底栏同为z-50，创建/取消被遮住；现弹层提高层级。SpatialScreen原先固定358px逻辑地图，320px视口右侧图块裁切；现用ResizeObserver读取地图尺寸，归一化已保存/新到达空间坐标。修复后的最右图块right=298，地图right=304，保留6px。

`before-fix-*`是修复前证据。旧`failure.*`也是中间失败记录；最终结果以`results.json`和编号截图为准，未覆盖/删除失败记录。原生容器固定390×844并整体等比缩放，与真正320px响应式页面是两种条件；`320-native-scaled-*`单独展示容器缩放。

复现：启动Vite后运行 `node tests/catalog-spatial-ui-smoke.mjs`（在FigmaMakeLatest-v3目录，需可用Playwright/Chromium）。支持 `SMARTPAW_PLAYWRIGHT` 指向已安装模块入口、`SMARTPAW_BROWSER_EXECUTABLE` 指向浏览器、`SMARTPAW_BASE_URL`、`SMARTPAW_QA_OUTPUT`，避免把本机临时路径当作跨电脑依赖。

同轮运行 `node --test tests/guideProgress.test.mjs tests/spaceLayout.test.mjs tests/nativeBridge.test.mjs tests/cameraPreviewLifecycle.test.mjs`：29/29通过，0失败、0跳过。项目根目录 `git diff --check` 通过。已人工查看390分类页与320书籍管理页截图，确认类别图案和书封正常显示；这不等同于完整Figma视觉验收。
