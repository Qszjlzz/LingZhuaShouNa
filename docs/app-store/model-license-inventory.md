# 模型、代码与图片许可清单

状态按仓库内容和模型元数据审计，不能替代法务核验。任何“待核”项在商业上架前都应取得原始仓库、权重发布者或版权方的书面许可，并把许可文件和版本号归档。

| 资产 | 仓库证据 | 当前判断 | 上架动作 |
| --- | --- | --- | --- |
| `Resources/Models/yolo11n-seg.mlpackage`、`yolo11n-seg-640.mlpackage` | Core ML metadata 含 `Ultralytics`、`AGPL-3.0 License` URL | AGPL-3.0 组件/权重标识；**当前没有商业许可** | 商业 App 需购买/签署 Ultralytics 商业许可或移除/替换，不能只添加一行 attribution |
| `yoloe-11s-seg.mlpackage`、`yoloe-context-seg.mlpackage`、`yolov8s-worldv2.mlpackage` | Core ML metadata 含 Ultralytics AGPL-3.0 标识 | 同上；**当前没有商业许可** | 同上，并保存训练数据/权重来源记录 |
| `Resources/Models/EdgeSAM/{encoder,decoder}` | 仓库无 LICENSE 文件；项目文档曾描述“非商业使用”，但未附原始许可 | **待核** | 找到准确仓库 commit、权重条款和商业许可；未核前不要用于商业发行 |
| `Resources/Models/mobileclip_s0_{image,text}.mlpackage` | 仅有 Core ML package metadata，无随仓库许可文本 | **待核** | 核对原始权重许可、商标和再分发条款；保留下载来源与 hash |
| `Services/MobileCLIP/*` | `CLIPTokenizer.swift` 保留 Hugging Face copyright/PR 链接，但项目没有完整第三方声明 | 需要补 attribution，许可证需按原仓库核验 | 将 Hugging Face/原作者 notice 放入 Settings 或 `ThirdPartyNotices` |
| `Resources/Models/DeepLabV3Int8LUT.mlmodel` | metadata 指向 TensorFlow 与 DeepLab research 源 | **待核** | 核对 TensorFlow/模型仓库许可证和模型权重再分发条件 |
| `FigmaMakeLatest-v3/ATTRIBUTIONS.md` | 声明 shadcn/ui MIT、Unsplash license | 部分已记录 | 确认运行时 Web bundle 使用的每张外部图片仍符合来源条款，补齐版本/URL |
| `Resources` 中六张 `external-*`、`eval-*` 评测图片 | 文件名包含 pexels、imweb、editthispic 等来源线索，未见逐文件许可记录；已从 Release 排除并核验归档 | **仅保留 Debug 评测，来源待核** | 不得作为商店宣传或再加入发行包；如要使用须补逐图许可 |

## 关键原则

- `AGPL-3.0` 不是“开源所以可直接放进 App Store”的证明；静态链接/衍生作品和网络服务边界需要法务判断。Ultralytics 另有商业许可路径，必须以其当前条款和购买记录为准。
- 模型 metadata 中的 URL 只能作为线索。上架包应随项目保存原始 license、权重版本和 SHA-256，避免日后无法证明来源。
- 这份清单没有伪造作者、邮箱、购买记录或许可证；所有待核项都是外部阻塞。
