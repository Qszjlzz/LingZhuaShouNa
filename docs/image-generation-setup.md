# 当前 BeeAPI 生图配置（开发包）

当前 App 的生图 Key 与「我的 → AI 设置」里的文字/识别 Key 是两套配置。生图设置页目前只有状态读取，没有可填写 Key 的生产界面；不要把 Key 填进聊天框或当成已接好的设置页。以下是当前 Debug 包已经使用的实际导入入口。

1. 在工程根目录把 `Resources/image-generation.example.json` 复制为 `Resources/image-generation.json`。该文件已被 gitignore 排除，也不会打进 App。
2. 只在本机编辑：`enabled` 设为 `true`，`apiKey` 填供应商的 Key；`endpoint` 为 `https://beeapi.dev/v1/images/edits`，`model` 为 `gpt-image-2`，`size` 为 `1024x1024`。可将 `timeoutSeconds` 设为 `300`；本次一次真实请求用了112.67秒。不要截图、打印或提交密钥。
3. 连接并解锁 iPhone；用 xcrun devicectl list devices 查本机连接设备的 UDID。安装当前 Debug 包后，在项目根目录执行（替换 DEVICE_ID）：

```sh
DEVICE_ID="替换为连接设备的UDID"
xcrun devicectl device copy to \
  --device "$DEVICE_ID" \
  --domain-type appDataContainer --domain-identifier com.qszjlzz.smartpaw \
  --source Resources/image-generation.json \
  --destination Documents/image-generation-import.json
xcrun devicectl device process launch \
  --device "$DEVICE_ID" --terminate-existing \
  com.qszjlzz.smartpaw --import-image-generation-config
```

4. 启动时导入器将 Key 存入该设备钥匙串、非敏感配置存入 UserDefaults，成功后删除手机上的导入 JSON。升级安装一般保留这些数据；换手机需重新导入。此开关只存在于 Debug 构建。
5. 拍摄空间并选择方案后，点击效果图生成；第一次要在 App 中确认向配置的服务上传当前照片。仅配置成功不会上传照片，也不表示已经出图。失败时仍可继续本地整理方案。

普通方案预览与生图接口是独立路径。本机 Mac 已有一次真实供应商出图证据，见 `quality/image-provider-20261023.md`；手机网络出图、保真和真实 HTTPS 返回下载仍需分别验收。供应商 Key 及额度在其官方账户管理页获取，本说明不猜测其管理页按钮或充值规则。


## 保存前视觉复核（当前源码）

生图Key和视觉Key仍是独立配置。当前生产预览还要求“我的→AI设置”已启用有效视觉服务并同意照片上传；生图完成后会把原图和结果图提交该视觉服务对照，再决定是否保存。会增加一次视觉请求的时间与费用，复核失败、不确定、不可用或取消时不保存，页面可以重试或明确使用文字方案继续。旧缓存由v3提示协议隔离。模型复核可能错判，不构成物品保真保证；本轮实测生成器仍复制金属夹，已知坏图被复核拒绝，不能称生图效果达标。手机安装、密钥导入和最终验收仍集中在最后阶段。
