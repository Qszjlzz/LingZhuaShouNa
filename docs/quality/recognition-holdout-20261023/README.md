# 真实照片留出集工作材料

状态：2026-10-23，未采集完成、未冻结、未执行；0 / 50 合格图。完整审计见 [状态记录](../recognition-holdout-status-20261023.md)。

| 文件 | 当前内容 | 使用方式 |
| --- | --- | --- |
| legacy-inventory.json | 26 个旧图像文件的 SHA-256、来源、使用情况和排除原因 | 审计库存，不能作为新 holdout 清单 |
| collection-intake.csv | 50 个计划槽位，无原图和标注；35 桌面 + 15 茶几仅是建议 | 收到授权原图后按实际来源填，记录同一家庭 / 空间 / 场景分组 |
| object-annotations.csv | 仅字段头 | 类别目录和规则冻结后逐实例完整标注；框为左上角 x/y + 宽/高、全部归一化 0..1 |
| predictions.csv | 仅字段头 | 真值冻结后逐预测写入；pipeline 为 local_offline / cloud_enabled / local_fallback，stage 标明 raw / parsed / merged / user_visible |
| protocol-draft.json | 未冻结协议；十类、IoU、同义词、忽略规则和结果为空 | 先冻结协议再执行首次盲测；不能把 null 当成 0 分或通过 |

填写时保留原始照片不做覆盖编辑；清理敏感 EXIF 如有需要，保存脱敏副本并分别记录原始 / 副本哈希。仅本地评测的授权不自动包含向云端供应商上传的授权。同一场景换角度、裁剪或亮度变化要归入相同分组，避免跨开发 / 留出集泄漏。
