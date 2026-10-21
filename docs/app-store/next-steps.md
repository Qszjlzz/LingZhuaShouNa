# 从 BLOCKED 到可提交

以下步骤按外部阻塞的依赖顺序排列。它们需要账号管理员、产品/法务和真实硬件参与；仓库改动不能代替付费、签约或公网发布。

1. **准备发行资格。** 购买并完成 Apple Developer Program 组织/个人注册；在 App Store Connect 创建 `com.qszjlzz.smartpaw` 对应 App，完成适用协议、年龄分级及分发地区所需信息。在欧盟分发时完成 DSA trader 状态；若销售付费 App 或提供内购，再完成适用的税务、银行和付费协议。创建 Distribution 证书和 App Store provisioning profile，并确认团队能在 ASC 上传构建。
2. **准备构建环境。** 在支持 Xcode 26 的 macOS 上安装 Xcode 26，登录上述开发者团队，连接 iPhone 15 Pro Max 或同等真机。运行 `scripts/release-preflight.sh`；只有 Xcode 26 和 iOS 26 SDK 检查通过（脚本输出 `PASS`）才允许执行 Release archive。当前 Xcode 16.4 会触发硬失败，不能用其产物提交。
3. **解决模型许可。** 对每个 Ultralytics 权重版本取得商业许可或从工程和 Release target 移除/替换；把许可条款、购买凭据、版本和 SHA-256 放进内部合规档案。对 EdgeSAM、MobileCLIP、DeepLab 和外部图片取得原始来源与可商用再分发条款；没有证据就替换。脚本的 AGPL FAIL 必须归零。
4. **发布隐私和支持页面。** 由运营/法务准备真实 HTTPS 隐私政策、支持页和支持邮箱，说明照片本地处理、可选云 AI 的真实第三方、处理地区、留存/删除、密钥存储；当前“灵感”页只有 4 条原创离线技巧和本机完成记录/收藏，没有线上用户内容。上线页面后在无登录 Safari 中验证，替换 `metadata-draft.md` 的三个未具备项。
5. **补产品合规缺口。** 代码已在首次保存云端开关前要求用户明确同意；仍需在真实服务商确定后补齐服务方、处理地区、留存期限和删除/撤回说明，并在真机验证关闭开关时没有网络请求。当前版本没有线上社区或用户内容外发入口；若未来恢复评论/分享，再加入内容过滤、举报、封禁和公开联系方式并重新核查元数据。
6. **填写 ASC 隐私问卷。** 以真实云服务商条款为准申报照片/用户内容及第三方共享；manifest 的 `PhotosorVideos` 和 `UserDefaults` 声明不能替代 App Privacy 问卷。完成年龄分级、出口合规、价格、版权及适用的 EU trader 问卷。
7. **真机验收并提交。** 测试无网络本地扫描、相机/照片拒绝、云 AI 开关、删除数据、后台恢复、低存储，以及本机灵感记录和收藏。准备最终版本的真实界面截图、审核备注和（如需要）审核专用服务配置；归档后检查包内没有 Key、测试密钥、诊断样本或未授权素材，再上传 App Store Connect。建议先经 TestFlight 验收；外部 TestFlight 测试是本项目的验证建议，不是每次 App Review 提交的强制前置步骤。
