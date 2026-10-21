# Apple 规则引用

核验日期：2026-10-20（Asia/Shanghai）。链接均为 Apple 官方页面；提交前应重新打开页面确认规则没有更新。

## 构建与系统要求

- [Upcoming Requirements](https://developer.apple.com/news/upcoming-requirements/)：自 2026-04-28 起，上传到 App Store Connect 的 App 必须用 Xcode 26 或更高版本，并使用 iOS 26、iPadOS 26、tvOS 26、visionOS 26 或 watchOS 26 SDK 构建。当前工作站 `xcodebuild -version` 为 Xcode 16.4，因此不能作为最终上传环境。
- 同页说明自 2026-09-09 起上传的 iOS/iPadOS App 最低支持 iOS 13。本工程 `IPHONEOS_DEPLOYMENT_TARGET = 18.0`，满足最低版本，但真机和 Xcode 26 仍需重验。

## 完整性、元数据与用户内容

- [App Review Guidelines 2.1 App Completeness](https://developer.apple.com/app-store/review/guidelines/#performance)：提交版本应是最终版本，必要 URL 必须可访问，不能保留占位文本；需在真机上测试稳定性。当前版本没有账号后端，以本机游客使用，已移除虚假的登录/退出入口；如未来加入登录，审核备注应提供可用 demo account。
- [App Review Guidelines 2.3 Accurate Metadata](https://developer.apple.com/app-store/review/guidelines/#accurate-metadata)：截图、描述和实际能力必须一致；不能把静态演示图或占位社区内容描述为真实服务能力。
- [App Review Guidelines 1.2 User-Generated Content](https://developer.apple.com/app-store/review/guidelines/#user-generated-content)：当前可达版本的“灵感”页只有 4 条内置原创整理技巧，以及本机完成记录和收藏，没有线上发布、评论、点赞、关注或外发入口，因此不能按线上 UGC 服务描述。若未来恢复线上用户内容，再补内容过滤、举报、封禁和公开联系信息并重新核查 1.2。

## 隐私、照片与第三方 AI

- [App Review Guidelines 5.1.1 Data Collection and Storage](https://developer.apple.com/app-store/review/guidelines/#data-collection-and-storage) 与 [5.1.2 Data Use and Sharing](https://developer.apple.com/app-store/review/guidelines/#data-use-and-sharing)：相机/照片用途要与实际用途一致；向第三方 AI 发送照片前必须清楚说明共享对象、用途和处理方式并取得明确许可。当前代码已在保存云端开关前要求用户明确同意，但仍缺发布方、保留期限和删除方式的正式披露，需补真实服务商隐私政策和首次启用说明。
- [Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files) 与 [Required Reason API](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files/describing_use_of_required_reason_api)：`App/ AppViewModel.swift` 和服务层使用 `UserDefaults`；`Resources/PrivacyInfo.xcprivacy` 已声明 `NSPrivacyAccessedAPICategoryUserDefaults`、理由 `CA92.1`，并把可选云端模式下发送的照片列为 App Functionality 数据。App Store Connect 的 App Privacy 问卷仍需人工按真实数据流填写，manifest 不替代问卷；第三方服务的留存、处理地区和再利用必须按实际服务商申报。
- 本工程实际使用相机和 `PHPickerViewController` 选择图片；Release 配置保留 `NSCameraUsageDescription` 和 `NSPhotoLibraryUsageDescription`。没有发现 `PHPhotoLibrary` 写入或 `UIImageWriteToSavedPhotosAlbum`，所以没有添加 `NSPhotoLibraryAddUsageDescription`；若以后加入保存到系统相册，必须再加该说明并重审隐私问卷。

## 欧盟与其他账号项

- [DSA trader status requirement](https://developer.apple.com/news/upcoming-requirements/)：在欧盟分发需在 App Store Connect 提供并验证 trader status；当前没有已准备的付费开发者账号或 App Store Connect 记录，因此该项尚未具备。
- 2026 年 Apple 已更新年龄分级问题。App Store Connect 的 App Information 需完成新的年龄分级问卷；仓库无法证明该步骤已完成。
- 价格、出口合规、税务、内容权利、Distribution 证书、Bundle ID 和团队权限都属于账号/外部系统；当前这些账号能力尚未具备，不能由仓库变更代办。
