# 拍后部分物品入库开发验证

2026-10-23。新增可复用组件 ScanLibraryImport，供识别确认页和拍后方案页接入；此目录证据来自独立 React 浏览器夹具，尚未证明宿主两个入口已接入或通过手机验收。

组件使用自由整理相同的 libraryStorageKey / importLibraryItems，保存 native 稳定 ID 的本机副本。每次保存重新读取最新库，因此保留先前文件夹、排序和其他屏幕新保存的物品。同名不同 ID 保留；重复 ID 禁止重复添加。来源空间 ID、名称一并保存。界面明确显示“本机保存，暂未同步云端”，不修改原扫描记录。

Node itemLibrary.test.mjs：12/12 通过，其中新增 3 项覆盖候选映射、部分保存及并发重读、空选择/重复选择、读取失败/配额失败。浏览器 scan-library-import-ui-smoke.mjs：390/320 CSS px 共 16 项通过，page errors=[]。验证部分选择、同名不同实例、与自由整理共用物品、重新载入恢复、演示/个人隔离、存储失败保留选择且可重试、空来源及无横向溢出。

截图 320-01-selection.png / 390-01-selection.png 为部分选择；*-02-storage-failure.png 为配额失败。图片和文字均为合成测试数据，未使用用户实拍或付费生图。浏览器未连接相机或云同步服务。

重跑：在 FigmaMakeLatest-v3 启动 Vite 5183，设置 SMARTPAW_PLAYWRIGHT 为可用 playwright 模块绝对路径，运行 node tests/scan-library-import-ui-smoke.mjs。Node 逻辑验证：node --test tests/itemLibrary.test.mjs。
