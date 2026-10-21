# 整理引导进度修复与增量验收（2026-10-21）

本轮修复了真实原生方案下的清理、分类、复核和逐步执行衔接。**15 项 Node 测试、4 项原生定向测试及 390 × 844 的生产网页交互检查通过；实际 iOS 模拟器也已从相册选图走到两个真实步骤完成，并验证重启后仍待保存完成照。** 本报告只覆盖这次增量，不能据此判定全 App 功能完成或全部 Figma 页面一致。

## 1. 本轮修改

生效源码为 `FigmaMakeLatest-v3/src/app/components/ShootFlow.tsx`，进度与分组逻辑抽到 `FigmaMakeLatest-v3/src/app/guideProgress.ts`，对应测试在 `FigmaMakeLatest-v3/tests/`。

- 新方案从“清理 → 物品分类 → 真实归位步骤”开始。前两段是操作指引，不消耗原生计划中的步骤 UUID。
- 前置指引的阶段以 `smartpaw.guide.phase.v1:<planID>` 保存到网页 localStorage；已有原生完成进度时，以原生 active 步骤优先恢复。前置指引存储失败不会把真实步骤标为完成。
- 普通整理与重新点亮两条路径在生成方案后同步原生物品数据。分类卡按 `step.itemIDs` 关联物品，不再按数组位置借用其他物品。没有可关联名称时显示步骤标题；件数由去重后的 itemIDs 得出，缺少 ID 时不编造件数。
- 分类页恢复“复核 / 跳过 / 下一步”。复核按真实步骤状态显示清单，底部只返回引导，不能从此提前进入完成照。跳过只用于清理、分类这两段前置指引，不会增加原生完成数。
- 真实归位步骤通过方案 ID、当前 active UUID 和暂停状态检查后才发送完成命令；收到响应后确认对应步骤确实为 done，再刷新本地方案并进入下一个真实步骤。保存失败保留当前步骤供重试。
- 分类与归位卡片使用步骤 UUID 作 key。超过三组时横向滚动，恢复到后面的步骤时让当前归位卡进入可见区域。

完成照与归档仍由原生既有门槛控制。本轮没有新增“跳过真实步骤”的状态或归档规则。

## 2. 验收结果与证据范围

| 检查 | 本轮结果 | 能证明什么 |
| --- | --- | --- |
| `guideProgress.test.mjs` | **15 / 15 通过** | 前置指引恢复、真实进度优先、按 planID 隔离、itemID 分组、指定 UUID 推进、暂停/旧状态拒绝、错误响应和保存失败处理 |
| 生产 `dist` + Playwright | **通过，390 × 844，pageErrors 为空** | 浏览器实际渲染与点击路径；原生 bridge 是测试脚本模拟的，不是 Swift 保存或真机相机 |
| 源 dist / 内嵌网页资源 | **JS 字节一致** | 本报告写入时两者均为 `index-Cym_NAvg.js`，SHA-256 为 `9d79b5dbf4223964e53ae20becca5d6b6581a2d43c77d15133f7603ea45ea31f` |
| ShootFlow 动效声明 AST 比对 | **通过：54 → 54 个 motion 元素，属性序列一致** | 保留指定的 JSX 动效声明；不证明真机帧率或所有路由均能触发动画 |
| 4 项原生定向测试 | **4 / 4 通过** | 主代理已解析 xcresult：total 4、passed 4、failed 0、skipped 0。仅证明这四项定向覆盖，不能扩大为识别质量或全 App 回归通过 |
| 实际 iOS 模拟器普通整理主线 | **本轮限定路线通过** | 最终 `index-Cym_NAvg.js` 包安装启动无白屏；从相册选图、生成方案到两个真实 UUID 完成，并只读核对原生持久状态；未拍完成照，重启仍显示“待保存完成照” |

Playwright 检查由 `FigmaMakeLatest-v3/tests/guide-ui-smoke.mjs` 执行，读取生产 dist，以模拟 bridge 提供带状态的测试方案。测试中还用本地照片替代远端场景图。它会保存模拟状态以验证页面刷新，未向 Swift 持久层写入这些 fixture。

交互检查覆盖：

1. 新方案到达清理 Step 1/5、分类 Step 2/5 和复核；复核/返回/刷新均不完成原生步骤。
2. 分类刷新后仍为分类；跳过分类后进入首个真实步骤，模拟原生完成数保持为 0，刷新仍能恢复。
3. 一次保存失败停在当前真实步骤，随后可重试。三个真实 UUID 逐个完成，最终进入整理清单；未拍完成照时没有发送归档命令，完成后刷新恢复完成提示。
4. 11 组分类卡保持可读宽度且不造成整页横向溢出；恢复最后一组时当前归位卡可见。

证据目录为 [`docs/handoff/evidence/guide-20261021/`](../handoff/evidence/guide-20261021/)。浏览器结构化结果见 [`result.json`](../handoff/evidence/guide-20261021/result.json)，原生四项测试摘要见 [`native-test-summary.json`](../handoff/evidence/guide-20261021/native-test-summary.json)。[`resource-manifest.json`](../handoff/evidence/guide-20261021/resource-manifest.json) 记录源 dist、仓库内嵌网页、构建 App 与模拟器实际安装包的相同指纹；上一轮根 evidence 中的资源清单是历史快照。

| 截图 | 对应状态 |
| --- | --- |
| [01-prepare.png](../handoff/evidence/guide-20261021/01-prepare.png) | 新方案清理指引 |
| [02-classify.png](../handoff/evidence/guide-20261021/02-classify.png) | 三组分类卡与操作栏 |
| [03-review-before-work.png](../handoff/evidence/guide-20261021/03-review-before-work.png) | 尚未归位时的复核 |
| [04-save-failure.png](../handoff/evidence/guide-20261021/04-save-failure.png) | 保存失败、当前步骤可重试 |
| [05-completed-checklist.png](../handoff/evidence/guide-20261021/05-completed-checklist.png) | 三个真实步骤完成后的清单 |
| [06-eleven-classification-groups.png](../handoff/evidence/guide-20261021/06-eleven-classification-groups.png) | 11 组分类卡横向布局 |
| [07-restored-last-group.png](../handoff/evidence/guide-20261021/07-restored-last-group.png) | 最后一组恢复并自动进入可见区 |

### 实际 iOS 模拟器操作与持久状态

本轮使用 iPhone 16 Pro、iOS 18.5 模拟器，安装并启动包含 `index-Cym_NAvg.js` 的最终构建，首页正常加载，无白屏。操作从 App 正常入口开始，通过相册选择仓库的 `Resources/ExternalScanTests/external-cluttered-study-pexels.jpg`，经过检查照片、提交、生成快速整理方案、确认方案和单区域选择后进入引导。此项使用真实原生 bridge 和存储，和前述 Playwright 的模拟 bridge 验收分开记录。

| 实际操作阶段 | 界面与原生状态核对 |
| --- | --- |
| 清理 → 分类 | 清理为 Step 1/4，分类为 Step 2/4；分类卡对应真实书籍 1 件、电子产品 2 件 |
| 复核 → 返回分类 | 复核两项均未完成，返回后仍在分类 |
| 跳过分类 → 首个归位步骤 | 原生步骤仍为 `active, pending`，done 数为 0；跳过指引没有把实际工作标为完成 |
| 首个真实步骤点击“下一步” | 保存第一个 UUID 后状态为 `done, active`，进入第二个真实步骤 |
| 完成第二个真实步骤 | 两个 UUID 状态为 `done, done`；庆祝页准确显示 2 步，清单两项打勾 |
| 强制终止并重启 | 空间页恢复为 100%、“待保存完成照”；整个过程中未拍完成照，`completedPlans` 始终为 0 |

上述关键阶段均已只读核对真实原生存储中的步骤及归档状态。步骤完成与成果归档仍保持分离；100% 仅表示本方案两个归位步骤已完成，不代表已保存完成照或已归档。

| 模拟器截图 | 对应状态 |
| --- | --- |
| [08-native-cleaning.png](../handoff/evidence/guide-20261021/08-native-cleaning.png) | 正常入口生成方案后的清理 Step 1/4 |
| [09-native-classify.png](../handoff/evidence/guide-20261021/09-native-classify.png) | 分类 Step 2/4：书籍 1 件、电子产品 2 件 |
| [10-native-review.png](../handoff/evidence/guide-20261021/10-native-review.png) | 归位前复核，两项均未完成 |
| [11-native-second-step.png](../handoff/evidence/guide-20261021/11-native-second-step.png) | 第一 UUID 保存完成，第二步骤进入 active |
| [12-native-completed.png](../handoff/evidence/guide-20261021/12-native-completed.png) | 两个真实步骤完成，庆祝页显示 2 步 |
| [13-native-checklist.png](../handoff/evidence/guide-20261021/13-native-checklist.png) | 原生状态均为 done，清单两项打勾 |
| [14-native-restarted.png](../handoff/evidence/guide-20261021/14-native-restarted.png) | 强制终止后重启，100% 且待保存完成照 |

本次使用模拟器相册导入照片，没有验证真机相机。本轮没有重走完成照保存归档、重新点亮路线、实际 App UI 下的保存失败重试或前置 localStorage 阶段在强制重启后的恢复；后两项已有 helper / 浏览器检查，仍不能将其扩大为实际 App 验收通过。

### 动效比对方法

独立审查使用仓库已安装的 Babel parser，分别解析工作树文件与修复前 HEAD `38b9171` 的 `ShootFlow.tsx`，提取所有 `motion.*` JSX 开标签及 `initial / animate / exit / transition / whileTap / whileHover / layout / layoutId` 属性。剔除 `loc / start / end / extra` 和注释等位置元数据后按出现顺序比较。

结果为 HEAD 54 个、当前 54 个，属性序列完全一致，首个差异索引为 `-1`。这项检查不覆盖全部 CSS、手写 DOM 粒子动画的运行表现，也不替代设备上的动效验收。

### 原生定向覆盖

本次运行环境为 Xcode 16.4、iOS 18.5、arm64、iPhone 16 Pro 模拟器。通过的四项用例为：

- `testPlanProgressMovesFromZeroToComplete`
- `testCompletionRequiresAfterPhotoBeforeArchiving`
- `testFailedWritesKeepManualItemsAndStepProgressRetryable`
- `testPlanPausePersistsAcrossViewModelRestartAndResumeKeepsProgress`

原工作站结果为 `/tmp/smartpaw-guide-20261021-native.xcresult`，测试日志为 `/tmp/smartpaw-guide-20261021-native.log`，最终构建日志为 `/tmp/smartpaw-guide-20261021-build.log`。这些是本机临时路径，不会随 Git 克隆迁移；跨电脑应按下节复跑。这四项本身验证原生进度、完成照前置条件、写入失败回滚与重启暂停恢复，不验证照片识别质量或新网页与真实 bridge 的完整操作路线；实际 App 操作覆盖另见上节。

## 3. 新电脑复跑

以下每段命令独立从仓库根目录开始，不依赖原工作站的 Codex runtime 绝对路径。准备 Node.js 24、支持当前锁文件的 pnpm；同步内嵌网页另需 Python 3。

### 逻辑测试与网页构建

```sh
cd FigmaMakeLatest-v3
pnpm install --frozen-lockfile
node --test tests/guideProgress.test.mjs
# 也可运行 pnpm run test:guide
pnpm run build
cd ..

# 构建网页并原子替换 App 内嵌资源；脚本支持 npm 或 pnpm。
sh scripts/build-bundled-web.sh
```

仅运行 `pnpm run build` 只会更新 dist。要让 iOS App 使用修改后的网页，必须同步 `Resources/FigmaMakeLatestWeb`，再用 Xcode 构建并安装 App。

### 原生四项定向测试

先用 `xcrun simctl list devices available` 查找当前电脑的 iPhone 模拟器 ID，替换下面的 `YOUR_SIMULATOR_UDID`；不要沿用原工作站的设备 ID。

```sh
SMARTPAW_SIMULATOR_UDID='YOUR_SIMULATOR_UDID'
xcodebuild -project SmartPaw.xcodeproj -scheme SmartPaw -configuration Debug \
  -destination "platform=iOS Simulator,id=$SMARTPAW_SIMULATOR_UDID" \
  -derivedDataPath /tmp/smartpaw-guide-derived CODE_SIGNING_ALLOWED=NO \
  -only-testing:SmartPawTests/SmartPawTests/testPlanProgressMovesFromZeroToComplete \
  -only-testing:SmartPawTests/SmartPawTests/testCompletionRequiresAfterPhotoBeforeArchiving \
  -only-testing:SmartPawTests/SmartPawTests/testFailedWritesKeepManualItemsAndStepProgressRetryable \
  -only-testing:SmartPawTests/SmartPawTests/testPlanPausePersistsAcrossViewModelRestartAndResumeKeepsProgress \
  test
```

### 可选：浏览器交互测试

这项测试还需 Playwright 与 Chromium/Chrome。如果 Playwright 已能从项目测试脚本解析到，可在生产构建完成后直接运行：

```sh
cd FigmaMakeLatest-v3
SMARTPAW_EVIDENCE_DIR="$PWD/../outputs/guide-ui-smoke" node tests/guide-ui-smoke.mjs
```

若未安装 Playwright，可在独立临时目录安装，避免只为复跑测试改动项目依赖清单：

```sh
task_tools_dir="$(mktemp -d "${TMPDIR:-/tmp}/smartpaw-guide-tools.XXXXXX")"
npm install --prefix "$task_tools_dir" --no-save playwright
"$task_tools_dir/node_modules/.bin/playwright" install chromium

cd FigmaMakeLatest-v3
NODE_PATH="$task_tools_dir/node_modules" \
SMARTPAW_EVIDENCE_DIR="$PWD/../outputs/guide-ui-smoke" \
node tests/guide-ui-smoke.mjs
```

`NODE_PATH` 仅在 Playwright 安装于项目解析路径以外时需要。若改用已有 Chrome/Chromium，可额外设置 `SMARTPAW_CHROME_PATH` 为其可执行文件路径；不设置时使用 Playwright 安装的 Chromium。`SMARTPAW_EVIDENCE_DIR` 可选，建议复跑输出到 `outputs`，保留已提交的验收截图。测试脚本会启动临时本地服务，结束时关闭服务与浏览器。

## 4. 仍需继续完成

- Figma 独立分类插画尚未提取。当前橙卡使用真实分组与通用图标，不应称为原插画的精确复刻；不能用整屏设计截图代替产品 UI。
- 真实多物理区域尚未实现。`StorageStep.zone` 是归位目的地，不是照片中的物理区域；不能把书架、抽屉等目的地假装为区域一、区域二的识别结果。
- 真实执行步骤的跳过尚未实现。目前只允许跳过清理、分类指引，实际步骤仍须保存完成后推进。若要支持真实跳过，需另行定义持久化状态、进度、完成照、归档和成就规则并补测。
- 实际 App 已验证普通整理路线的清理、分类、复核、两个真实步骤保存，以及全部步骤完成后强制重启仍待保存完成照。本轮尚未重走完成照保存归档、重新点亮、实际 UI 保存失败重试和前置 localStorage 阶段的重启恢复；真机相机、系统权限与设备动效表现也不由本报告证明。
- 全 App / Figma 正式手机画板逐屏验收未通过；其他页面、物理分区和插画差异仍应沿 [HANDOFF.md](../../HANDOFF.md) 继续处理。
- [此前原生全量报告](native-test-results-20261021.md) 的 **76 项、70 通过、6 失败** 是上一轮结果，不是这次修改后的新全量测试。15 项 Node 测试和 4 项原生定向测试不能替代新全量回归。
