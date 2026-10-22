import SwiftUI
import WebKit
import UIKit
import PhotosUI
import UniformTypeIdentifiers

struct CurrentFigmaMakeWebView: UIViewRepresentable {
    @EnvironmentObject private var viewModel: AppViewModel

    func makeCoordinator() -> Coordinator { Coordinator(viewModel: viewModel) }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.userContentController.add(context.coordinator, name: "smartpaw")
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.bounces = false
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        Self.loadBundle(in: webView)
        // 识别模型放后台提前加载：第一次拍照时不必等编译，诊断信息也能立刻给出。
        Task.detached(priority: .utility) {
            let names = YOLOSegmentationScanService.loadedModelNames
            print("SMARTPAW_MODELS \(names.count) \(names.joined(separator: "、"))")
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.viewModel = viewModel
        guard webView.url == nil else { return }
        Self.loadBundle(in: webView)
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.stopCaptureWork()
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "smartpaw")
        webView.navigationDelegate = nil
    }

    @MainActor
    final class Coordinator: NSObject, WKScriptMessageHandler, UIImagePickerControllerDelegate,
        UINavigationControllerDelegate, PHPickerViewControllerDelegate {
        weak var webView: WKWebView?
        var viewModel: AppViewModel
        private var pendingRequestID = ""
        private var capturePurpose = "scan"
        private var pendingCaptureID: String?
        private var pendingProofImage: (image: UIImage, spaceID: UUID, planID: UUID)?
        /// 拍完照后的识别任务链。快门不等识别，识别在后台串行跑完再通知网页。
        private var scanQueueTask: Task<Void, Never>?
        private var scanQueueTaskID = UUID()
        private var scanQueueFinished = true
        private var photoScanResults: [String: [DetectedItem]] = [:]
        private var photoScanErrors: [String: String] = [:]
        private var scanSessionGeneration = 0
        private var disorderTask: Task<VisualDisorderAssessment, Error>?
        private var disorderToken = UUID()
        private var imageGenerationTask: Task<URL, Error>?
        private var imageGenerationToken = UUID()
        private weak var imageConsentAlert: UIAlertController?
        private var pendingImageConsent: ((Bool) -> Void)?

        init(viewModel: AppViewModel) { self.viewModel = viewModel }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.frameInfo.isMainFrame,
                  let request = message.body as? [String: Any],
                  let requestID = request["requestId"] as? String,
                  let command = request["command"] as? String else { return }
            let payload = request["payload"] as? [String: Any] ?? [:]
            Task { await handle(requestID: requestID, command: command, payload: payload) }
        }

        private func handle(requestID: String, command: String, payload: [String: Any]) async {
            switch command {
            case "state.get": respond(requestID, data: stateObject())
            case "presentation.mode.set":
                guard let enabled = payload["enabled"] as? Bool else { return fail(requestID, "请选择数据来源") }
                stopCaptureWork()
                guard viewModel.setPresentationMode(enabled) else { return fail(requestID, viewModel.message ?? "数据切换失败") }
                respondWithState(requestID)
            case "external.open":
                guard let rawURL = payload["url"] as? String, let url = URL(string: rawURL),
                      url.scheme?.lowercased() == "https", url.host != nil,
                      url.user == nil, url.password == nil else { return fail(requestID, "链接无效") }
                let opened = await UIApplication.shared.open(url)
                if opened { respond(requestID, data: ["opened": true]) }
                else { fail(requestID, "无法打开链接，请稍后重试") }
            case "llm.settings.get": respond(requestID, data: ["isEnabled": viewModel.llmSettings.isEnabled, "hasCloudConsent": viewModel.llmSettings.hasCloudConsent, "endpoint": viewModel.llmSettings.endpoint, "model": viewModel.llmSettings.model, "visionEndpoint": viewModel.llmSettings.visionEndpoint, "visionModel": viewModel.llmSettings.visionModel, "hasAPIKey": !viewModel.llmSettings.apiKey.isEmpty])
            case "llm.settings.save":
                // 设置页不回显已保存的密钥，输入框通常是空的；空值一律表示"不改动"，
                // 否则用户只改个开关就会把密钥清空。
                let incomingKey = (payload["apiKey"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let resolvedKey = payload["clearAPIKey"] as? Bool == true ? "" : (incomingKey.isEmpty ? viewModel.llmSettings.apiKey : incomingKey)
                let incomingEndpoint = (payload["endpoint"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let incomingModel = (payload["model"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let settings = LLMSettings(
                    isEnabled: payload["isEnabled"] as? Bool ?? false,
                    endpoint: incomingEndpoint.isEmpty ? viewModel.llmSettings.endpoint : incomingEndpoint,
                    apiKey: resolvedKey,
                    model: incomingModel.isEmpty ? viewModel.llmSettings.model : incomingModel,
                    visionEndpoint: payload["visionEndpoint"] as? String ?? "",
                    visionModel: payload["visionModel"] as? String ?? "",
                    hasCloudConsent: payload["hasCloudConsent"] as? Bool ?? false
                )
                cancelDisorderAssessment()
                cancelImageGeneration()
                guard viewModel.saveLLMSettings(settings) else { return fail(requestID, viewModel.message ?? "AI 设置保存失败") }
                respond(requestID, data: ["saved": true])
            case "llm.test":
                let incomingKey = (payload["apiKey"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let settings = LLMSettings(isEnabled: true, endpoint: payload["endpoint"] as? String ?? viewModel.llmSettings.endpoint, apiKey: incomingKey.isEmpty ? viewModel.llmSettings.apiKey : incomingKey, model: payload["model"] as? String ?? viewModel.llmSettings.model, visionEndpoint: payload["visionEndpoint"] as? String ?? viewModel.llmSettings.visionEndpoint, visionModel: payload["visionModel"] as? String ?? viewModel.llmSettings.visionModel, hasCloudConsent: payload["hasCloudConsent"] as? Bool ?? false)
                await viewModel.testLLMConnection(settings)
                switch viewModel.llmConnectionState {
                case .success(let message): respond(requestID, data: ["state": "success", "message": message])
                case .failure(let message): fail(requestID, message)
                default: fail(requestID, "连接测试未完成，请重试。")
                }
            case "image.settings.get":
                respond(requestID, data: ImageGenerationManager.shared.statusObject())
            case "image.preview.restore":
                restoreImagePreview(payload, requestID: requestID)
            case "image.preview.generate":
                await generateImagePreview(payload, requestID: requestID)
            case "image.preview.cancel":
                cancelImageGeneration()
                respond(requestID, data: ["cancelled": true])
            case "data.reset":
                stopCaptureWork()
                guard viewModel.resetLocalData() else { return fail(requestID, viewModel.message ?? "数据删除失败") }
                if !viewModel.isPresentationMode {
                    await WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast)
                }
                respondWithState(requestID)
            case "capture.open": openCapture(requestID: requestID, payload: payload)
            case "capture.after.cancel":
                pendingProofImage = nil
                respond(requestID, data: ["cancelled": true])
            case "capture.after.commit":
                guard let proof = pendingProofImage,
                      let space = viewModel.spaces.first(where: { $0.id == viewModel.selectedSpaceID }),
                      space.id == proof.spaceID, space.activePlan?.id == proof.planID else { return fail(requestID, "方案已改变，请重新拍摄完成照") }
                guard finishPlan(with: proof.image) else { return fail(requestID, viewModel.message ?? "完成照保存失败") }
                pendingProofImage = nil
                respondWithState(requestID)
            case "scan.open": openScanStudio(requestID: requestID, payload: payload)
            case "camera.preview.warm":
                await CameraPreviewOverlay.shared.warmUp()
                respond(requestID, data: ["ok": CameraEngine.shared.isReady])
            case "camera.preview.show": await showInlinePreview(requestID: requestID)
            case "camera.preview.start": await startInlinePreview(requestID: requestID, payload: payload)
            case "camera.preview.frame": updateInlinePreviewFrame(payload: payload); respond(requestID, data: ["ok": true])
            case "camera.preview.stop": CameraPreviewOverlay.shared.stop(); respond(requestID, data: ["ok": true])
            // AR 实时扫描：连续取帧 → 本地模型（不联网、不出 mask）→ 页面只叠加名称标签。
            case "ar.scan.start": await startARScan(requestID: requestID)
            case "ar.scan.poll": pollARScan(requestID: requestID)
            case "ar.scan.stop": stopARScan(); respond(requestID, data: ["ok": true])
            case "camera.capture": await captureInline(requestID: requestID, payload: payload)
            case "scan.begin":
                cancelDisorderAssessment()
                scanSessionGeneration += 1
                scanQueueTask?.cancel()
                scanQueueTask = nil
                scanQueueTaskID = UUID()
                scanQueueFinished = true
                photoScanResults = [:]
                photoScanErrors = [:]
                viewModel.cancelScanWork()
                viewModel.beginPhotoScanSession()
                respond(requestID, data: ["ready": true])
            case "scan.cancel":
                stopCaptureWork()
                respond(requestID, data: ["cancelled": true])
            case "scan.results":
                guard let captureID = payload["captureID"] as? String else { return fail(requestID, "缺少照片编号") }
                if let items = photoScanResults[captureID] {
                    respond(requestID, data: ["ready": true, "items": nativeItemObjects(items, captureID: captureID)])
                } else {
                    respond(requestID, data: ["ready": false, "items": []])
                }
            case "scan.await":
                let generation = scanSessionGeneration
                let spaceID = viewModel.selectedSpaceID
                if let captureIDs = payload["captureIDs"] as? [String] {
                    let deadline = Date().addingTimeInterval(300)
                    while captureIDs.contains(where: { photoScanResults[$0] == nil && photoScanErrors[$0] == nil }) {
                        guard generation == scanSessionGeneration, spaceID == viewModel.selectedSpaceID,
                              !Task.isCancelled else { return fail(requestID, "本次扫描已结束，请重试") }
                        guard Date() < deadline else { return fail(requestID, "照片识别仍未完成，请稍后重新提交") }
                        try? await Task.sleep(nanoseconds: 100_000_000)
                    }
                    guard generation == scanSessionGeneration, spaceID == viewModel.selectedSpaceID,
                          !Task.isCancelled else { return fail(requestID, "本次扫描已结束，请重试") }
                    if let error = captureIDs.compactMap({ photoScanErrors[$0] }).first {
                        return fail(requestID, error)
                    }
                    let items = mergePhotoScanResults(captureIDs)
                    guard viewModel.replaceScannedItems(items) else { return fail(requestID, viewModel.message ?? "扫描结果保存失败") }
                    viewModel.commitPhotoScanSession()
                    let sourceItems = captureIDs.flatMap { captureID in
                        (photoScanResults[captureID] ?? []).map { item in
                            nativeItemObject(item, captureID: captureID)
                        }
                    }
                    respond(requestID, data: ["state": stateObject(), "items": sourceItems])
                    return
                }
                let deadline = Date().addingTimeInterval(300)
                while !scanQueueFinished {
                    guard generation == scanSessionGeneration, spaceID == viewModel.selectedSpaceID,
                          !Task.isCancelled else { return fail(requestID, "本次扫描已结束，请重试") }
                    guard Date() < deadline else {
                        return fail(requestID, "照片识别仍未完成，请稍后重新提交")
                    }
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
                guard generation == scanSessionGeneration, spaceID == viewModel.selectedSpaceID,
                      !Task.isCancelled else { return fail(requestID, "本次扫描已结束，请重试") }
                guard viewModel.lastScanPersisted else { return fail(requestID, viewModel.message ?? "扫描结果保存失败，请重试") }
                viewModel.commitPhotoScanSession()
                respondWithState(requestID)
            case "scan.diagnose":
                respond(requestID, data: [
                    "modelCount": YOLOSegmentationScanService.loadedModelCount,
                    "models": YOLOSegmentationScanService.loadedModelNames,
                    "cloudEnabled": viewModel.llmSettings.canRequestVision,
                    "visionModel": viewModel.llmSettings.resolvedVisionModel,
                    "detail": RecognitionRouter.shared.diagnostics,
                ] as [String: Any])
            case "space.select":
                guard let id = uuid(payload["id"]), viewModel.spaces.contains(where: { $0.id == id }) else { return fail(requestID, "空间不存在") }
                cancelDisorderAssessment()
                cancelImageGeneration()
                viewModel.selectSpace(id); respondWithState(requestID)
            case "space.disorder.analyze":
                await analyzeDisorder(payload, requestID: requestID)
            case "space.disorder.cancel":
                cancelDisorderAssessment()
                respond(requestID, data: ["cancelled": true])
            case "space.photos":
                guard let id = uuid(payload["id"]), let space = viewModel.spaces.first(where: { $0.id == id }) else { return fail(requestID, "空间不存在") }
                var photos: [String: String] = [:]
                for (key, name, asset) in [("before", space.beforeImageName, space.beforeAssetName), ("after", space.afterImageName, space.afterAssetName)] {
                    let image: UIImage?
                    if let url = viewModel.imageURL(for: name), let data = try? Data(contentsOf: url) {
                        image = UIImage.downsampled(data: data, maxPixelSize: 640)
                    } else if viewModel.isPresentationMode, let asset {
                        image = UIImage(named: asset)
                    } else { image = nil }
                    if let image, let preview = Self.thumbnailDataURL(for: image) { photos[key] = preview }
                }
                respond(requestID, data: photos)
            case "space.add":
                guard let id = viewModel.addSpace(name: payload["name"] as? String ?? "新空间") else { return fail(requestID, "空间名称不能为空") }
                respond(requestID, data: ["id": id.uuidString, "state": stateObject()])
            case "space.rename":
                guard let id = uuid(payload["id"]) else { return fail(requestID, "空间 ID 无效") }
                guard let name = payload["name"] as? String, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return fail(requestID, "空间名称不能为空") }
                guard viewModel.renameSpace(id, name: name) else { return fail(requestID, viewModel.message ?? "空间保存失败，请重试") }
                respondWithState(requestID)
            case "space.delete":
                guard let id = uuid(payload["id"]) else { return fail(requestID, "空间 ID 无效") }
                guard viewModel.spaces.count > 1 else { return fail(requestID, "至少保留一个空间") }
                guard viewModel.deleteSpace(id) else { return fail(requestID, viewModel.message ?? "空间删除失败，请重试") }
                respondWithState(requestID)
            case "items.save": saveItems(payload, requestID: requestID)
            case "item.add":
                guard let rawCategory = payload["category"] as? String,
                      let category = ItemCategory(webValue: rawCategory) else { return fail(requestID, "物品类别无效") }
                guard viewModel.addManualItem(name: payload["name"] as? String ?? "", category: category, suggestedZone: payload["suggestedZone"] as? String, forScan: true) else { return fail(requestID, viewModel.message ?? "物品保存失败") }
                respondWithState(requestID)
            case "item.zone.update":
                guard let id = uuid(payload["id"]),
                      let zone = (payload["suggestedZone"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !zone.isEmpty else { return fail(requestID, "分组名称不能为空") }
                guard var item = viewModel.catalogItems.first(where: { $0.id == id }) ?? viewModel.scannedItems.first(where: { $0.id == id }) else {
                    return fail(requestID, "物品不存在")
                }
                item.suggestedZone = zone
                guard viewModel.updateCatalogItem(item) else { return fail(requestID, viewModel.message ?? "分组保存失败，请重试") }
                respondWithState(requestID)
            case "item.delete":
                guard let id = uuid(payload["id"]) else { return fail(requestID, "物品 ID 无效") }
                guard viewModel.removeCatalogItem(id) else { return fail(requestID, viewModel.message ?? "物品删除失败，请重试") }
                respondWithState(requestID)
            case "plan.generate": await generatePlan(payload, requestID: requestID)
            case "plan.reuse":
                guard let spaceID = uuid(payload["spaceID"]), let planID = uuid(payload["planID"]) else { return fail(requestID, "原方案参数无效") }
                guard viewModel.reusePlan(spaceID: spaceID, planID: planID) else { return fail(requestID, viewModel.message ?? "原方案恢复失败") }
                respondWithState(requestID)
            case "plan.pause.set":
                guard let spaceID = uuid(payload["spaceID"]),
                      let planID = uuid(payload["planID"]),
                      let isPaused = payload["isPaused"] as? Bool else {
                    return fail(requestID, "方案暂停参数无效")
                }
                guard viewModel.setPlanPaused(spaceID: spaceID, planID: planID, isPaused: isPaused) else {
                    return fail(requestID, viewModel.message ?? "方案状态保存失败，请重试")
                }
                respondWithState(requestID)
            case "chat.send": await sendChat(payload, requestID: requestID)
            case "plan.step.complete":
                guard let id = uuid(payload["id"]) else { return fail(requestID, "步骤 ID 无效") }
                guard viewModel.completeStep(id) else { return fail(requestID, viewModel.message ?? "步骤保存失败，请重试") }
                respondWithState(requestID)
            case "community.like": mutateCommunity(payload, requestID: requestID, action: viewModel.toggleCommunityLike)
            case "community.favorite": mutateCommunity(payload, requestID: requestID, action: viewModel.toggleCommunityFavorite)
            case "community.follow":
                guard viewModel.toggleCommunityFollow(author: payload["author"] as? String ?? "") else { return fail(requestID, viewModel.message ?? "关注保存失败，请重试") }
                respondWithState(requestID)
            case "community.comment":
                guard let id = uuid(payload["id"]) else { return fail(requestID, "案例 ID 无效") }
                let body = payload["body"] as? String ?? payload["text"] as? String ?? ""
                guard !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return fail(requestID, "笔记不能为空") }
                guard viewModel.addCommunityComment(to: id, body: body) else { return fail(requestID, viewModel.message ?? "评论保存失败，请重试") }
                respondWithState(requestID)
            case "community.shareCompletion":
                guard viewModel.shareLatestCompletion() else { return fail(requestID, viewModel.message ?? "分享保存失败，请重试") }
                respondWithState(requestID)
            case "schedule.add":
                guard viewModel.addScheduleItem(title: payload["title"] as? String ?? "整理复盘", dueText: payload["dueText"] as? String ?? "明天", note: payload["note"] as? String ?? "") else { return fail(requestID, viewModel.message ?? "日程保存失败，请重试") }
                respondWithState(requestID)
            case "schedule.toggle":
                guard let id = uuid(payload["id"]) else { return fail(requestID, "日程 ID 无效") }
                guard viewModel.toggleScheduleItem(id) else { return fail(requestID, viewModel.message ?? "日程保存失败，请重试") }
                respondWithState(requestID)
            case "schedule.delete":
                guard let id = uuid(payload["id"]) else { return fail(requestID, "日程 ID 无效") }
                guard viewModel.deleteScheduleItem(id) else { return fail(requestID, viewModel.message ?? "日程删除失败，请重试") }
                respondWithState(requestID)
            default: fail(requestID, "暂不支持命令：\(command)")
            }
        }

        private func openCapture(requestID: String, payload: [String: Any]) {
            guard pendingRequestID.isEmpty else { return fail(requestID, "请先完成当前照片选择") }
            pendingRequestID = requestID
            capturePurpose = payload["purpose"] as? String ?? "scan"
            pendingCaptureID = payload["captureID"] as? String
            if payload["source"] as? String == "camera", UIImagePickerController.isSourceTypeAvailable(.camera) {
                presentCameraCapture()
            } else {
                var config = PHPickerConfiguration(photoLibrary: .shared())
                config.filter = .images; config.selectionLimit = capturePurpose == "scan" && pendingCaptureID == nil ? 6 : 1
                let picker = PHPickerViewController(configuration: config); picker.delegate = self
                topViewController()?.present(picker, animated: true)
            }
        }

        /// 拍摄统一走原生页：画面是原生的，照片留在原生侧，
        /// 只把 240px 缩略图回给网页做展示，避免大图 base64 撑爆 WebView。
        private func openScanStudio(requestID: String, payload: [String: Any]) {
            guard pendingRequestID.isEmpty else { return fail(requestID, "请先完成当前拍摄") }
            pendingRequestID = requestID
            capturePurpose = "scan"
            let wantsAR = payload["mode"] as? String == "ar"
            let single = payload["single"] as? Bool ?? false
            let studio = ScanStudioView(
                initialMode: wantsAR ? .ar : .photo,
                singleShot: single,
                onCommit: { [weak self] result in
                    guard let self else { return }
                    self.topViewController()?.dismiss(animated: true)
                    self.pendingRequestID = ""
                    self.consumeStudioResult(result, requestID: requestID)
                },
                onCancel: { [weak self] in
                    guard let self else { return }
                    self.topViewController()?.dismiss(animated: true)
                    self.cancelCapture()
                }
            )
            let host = UIHostingController(rootView: studio)
            host.modalPresentationStyle = .fullScreen
            host.modalTransitionStyle = .crossDissolve
            topViewController()?.present(host, animated: true)
        }

        private func consumeStudioResult(_ result: ScanStudioResult, requestID: String) {
            let generation = scanSessionGeneration
            Task {
                await viewModel.scanImages(result.images)
                guard generation == scanSessionGeneration else { return fail(requestID, "本次扫描已结束，请重新拍摄") }
                guard viewModel.lastScanPersisted else { return fail(requestID, viewModel.message ?? "识别结果保存失败，请重试") }
                emit(["requestId": requestID, "status": "success",
                      "data": ["previews": result.thumbnails, "state": stateObject()] as [String: Any]])
            }
        }

        /// 网页拍摄页内联取景：把实时画面垫在 WebView 底下，页面不跳走。
        private func startInlinePreview(requestID: String, payload: [String: Any]) async {
            guard let webView else { return fail(requestID, "WebView 未就绪") }
            var frame = CGRect(origin: .zero, size: webView.bounds.size)
            if let x = payload["x"] as? Double, let y = payload["y"] as? Double,
               let w = payload["width"] as? Double, let h = payload["height"] as? Double {
                frame = CGRect(x: x, y: y, width: w, height: h)
            }
            let ok = await CameraPreviewOverlay.shared.start(in: webView, frame: frame)
            // 起不来时把原因告诉网页：没授权和"被别的 App 占着"要给不同提示。
            let reason = ok ? "" : (CameraEngine.shared.permissionDenied ? "denied" : "unavailable")
            respond(requestID, data: ["ok": ok, "reason": reason])
        }

        /// 点拍摄按钮的瞬间调用：相机已经在待命，这里只把画面显示出来。
        /// 万一还没待命（首次授权、刚从后台回来）就顺手补一次启动，保证一定能出画面。
        private func showInlinePreview(requestID: String) async {
            guard let webView else { return fail(requestID, "WebView 未就绪") }
            var ok = CameraPreviewOverlay.shared.reveal()
            if !ok {
                await CameraPreviewOverlay.shared.arm(in: webView)
                ok = CameraPreviewOverlay.shared.reveal()
            }
            let reason = ok ? "" : (CameraEngine.shared.permissionDenied ? "denied" : "unavailable")
            respond(requestID, data: ["ok": ok, "reason": reason])
        }

        private func updateInlinePreviewFrame(payload: [String: Any]) {
            guard let x = payload["x"] as? Double, let y = payload["y"] as? Double,
                  let w = payload["width"] as? Double, let h = payload["height"] as? Double else { return }
            CameraPreviewOverlay.shared.updateFrame(CGRect(x: x, y: y, width: w, height: h))
        }

        /// 原地拍一张：不弹任何界面。缩略图立刻回给网页（秒出图），识别在后台排队跑。
        private func captureInline(requestID: String, payload: [String: Any] = [:]) async {
            let generation = scanSessionGeneration
            let spaceID = viewModel.selectedSpaceID
            let purpose = payload["purpose"] as? String
            guard let image = await CameraPreviewOverlay.shared.capture() else {
                // 相机没起来就明确告诉页面原因，页面据此提示重试（而不是弹系统相机）。
                let reason = CameraEngine.shared.permissionDenied ? "没有相机权限：去「设置 → 灵爪收纳」里打开相机" : "相机还没准备好，稍等一下再拍"
                return fail(requestID, reason)
            }
            guard generation == scanSessionGeneration, spaceID == viewModel.selectedSpaceID,
                  !Task.isCancelled else { return fail(requestID, "本次拍摄已结束，请重新拍摄") }
            // purpose=after 是「整理后打卡照」，只回缩略图；其余一律按扫描用途处理。
            if purpose == "after-preview" {
                stageCompletionPhoto(image, requestID: requestID)
                return
            }
            let isAfter = purpose == "after"
            capturePurpose = isAfter ? "after" : "scan"
            // 整理后照片必须先保存成功，再通知界面显示完成。
            let preview = Self.thumbnailDataURL(for: image)
            if isAfter {
                guard finishPlan(with: image) else { return fail(requestID, viewModel.message ?? "请先完成整理步骤") }
                respond(requestID, data: ["preview": preview as Any, "state": stateObject()])
                return
            }
            let captureID = payload["captureID"] as? String
            var captureResponse: [String: Any] = ["preview": preview as Any, "state": stateObject()]
            if let captureID { captureResponse["captureID"] = captureID }
            respond(requestID, data: captureResponse)
            // 整理后的照片不参与识别，避免把成果照里的物品重复计入本次扫描。
            let previous = scanQueueTask
            let taskID = UUID()
            scanQueueTaskID = taskID
            scanQueueFinished = false
            scanQueueTask = Task { [weak self] in
                defer {
                    if self?.scanQueueTaskID == taskID { self?.scanQueueFinished = true }
                }
                // 连拍时识别必须串行，否则两次扫描会同时读写 scannedItems。
                await previous?.value
                guard let self, !Task.isCancelled, generation == self.scanSessionGeneration else { return }
                let items = await self.viewModel.scanImages([image], accumulate: true)
                guard !Task.isCancelled, generation == self.scanSessionGeneration else { return }
                guard self.viewModel.lastScanPersisted else {
                    let error = self.viewModel.message ?? "识别结果保存失败，请重试"
                    if let captureID { self.photoScanErrors[captureID] = error }
                    self.emit(["event": "scan.error", "message": error])
                    return
                }
                if let captureID { self.photoScanResults[captureID] = items }
                self.emit(["event": "scan.updated", "state": self.stateObject()])
            }
        }

        private func mergePhotoScanResults(_ captureIDs: [String]) -> [DetectedItem] {
            // 每张照片的结果都是独立实例。按名称合并会把两张照片里同名的
            // 真实物品压成一个，并把其中一张的坐标错误地画到另一张照片上。
            return captureIDs.flatMap { photoScanResults[$0] ?? [] }
        }

        private func nativeItemObjects(_ items: [DetectedItem], captureID: String? = nil) -> [[String: Any]] {
            items.map { nativeItemObject($0, captureID: captureID) }
        }

        private func nativeItemObject(_ item: DetectedItem, captureID: String? = nil) -> [String: Any] {
            var object: [String: Any] = [
                "id": item.id.uuidString,
                "name": item.name,
                "category": item.category.rawValue,
                "confidence": item.confidence,
                "suggestedZone": item.suggestedZone,
                "isSelected": item.isSelected,
            ]
            if let captureID { object["captureID"] = captureID }
            if let hint = item.arHint {
                object["arHint"] = ["x": hint.x, "y": hint.y, "width": hint.width, "height": hint.height]
            }
            return object
        }

        /// 直接用 App 内置取景框拍照，避免跳到系统相机破坏演示连贯性。
        private func presentCameraCapture() {
            let cameraView = CameraCaptureView(
                onCapture: { [weak self] image in
                    guard let self else { return }
                    self.topViewController()?.dismiss(animated: true)
                    self.consume(images: [image])
                },
                onCancel: { [weak self] in
                    guard let self else { return }
                    self.topViewController()?.dismiss(animated: true)
                    self.cancelCapture()
                }
            )
            let host = UIHostingController(rootView: cameraView)
            host.modalPresentationStyle = .fullScreen
            topViewController()?.present(host, animated: true)
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            picker.dismiss(animated: true)
            guard let image = info[.originalImage] as? UIImage else { return failCapture("没有取得照片") }
            consume(images: [image])
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { picker.dismiss(animated: true); cancelCapture() }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard !results.isEmpty else { return cancelCapture() }
            let requestID = pendingRequestID
            let generation = scanSessionGeneration
            Task {
                var images: [UIImage] = []
                for result in results where result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                    if let image = await loadImage(from: result.itemProvider) { images.append(image) }
                }
                guard generation == scanSessionGeneration, requestID == pendingRequestID else { return }
                guard !images.isEmpty else { return failCapture("所选照片无法读取") }
                consume(images: images)
            }
        }

        /// 网页只需要一张能看的小图。原图留在原生侧做识别，不跨桥回传。
        private static func thumbnailDataURL(for image: UIImage, width: CGFloat = 640) -> String? {
            let ratio = image.size.height / max(image.size.width, 1)
            let target = CGSize(width: width, height: width * ratio)
            UIGraphicsBeginImageContextWithOptions(target, false, 1)
            image.draw(in: CGRect(origin: .zero, size: target))
            let scaled = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            guard let scaled, let data = scaled.jpegData(compressionQuality: 0.6) else { return nil }
            return "data:image/jpeg;base64," + data.base64EncodedString()
        }

        private func loadImage(from provider: NSItemProvider) async -> UIImage? {
            await withCheckedContinuation { continuation in
                provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, _ in
                    guard let url, let data = try? Data(contentsOf: url, options: .mappedIfSafe) else {
                        continuation.resume(returning: nil)
                        return
                    }
                    continuation.resume(returning: UIImage.downsampled(data: data))
                }
            }
        }

        private func consume(images: [UIImage], accumulate: Bool = false) {
            let requestID = pendingRequestID
            let captureID = pendingCaptureID
            pendingRequestID = ""
            pendingCaptureID = nil
            // 只回传小图：网页只做展示，识别用的是原生侧的原图。
            // 之前这里回传全分辨率 JPEG 的 base64，几张连拍就能把 WebView 撑到被系统杀掉。
            let preview = images.first.flatMap { Self.thumbnailDataURL(for: $0) }
            if capturePurpose == "after-preview", let image = images.first {
                stageCompletionPhoto(image, requestID: requestID)
                return
            }
            if capturePurpose == "after", let image = images.first {
                guard finishPlan(with: image) else { return fail(requestID, viewModel.message ?? "请先完成整理步骤") }
                respond(requestID, data: ["preview": preview as Any, "state": stateObject()]); return
            }
            let generation = scanSessionGeneration
            Task {
                let items = await viewModel.scanImages(images, accumulate: accumulate)
                guard generation == scanSessionGeneration else { return fail(requestID, "本次扫描已结束，请重新拍摄") }
                guard viewModel.lastScanPersisted else { return fail(requestID, viewModel.message ?? "识别结果保存失败，请重试") }
                if let captureID { photoScanResults[captureID] = items }
                respond(requestID, data: ["preview": preview as Any, "state": stateObject(), "items": nativeItemObjects(items, captureID: captureID)])
            }
        }

        private func stageCompletionPhoto(_ image: UIImage, requestID: String) {
            guard let space = viewModel.spaces.first(where: { $0.id == viewModel.selectedSpaceID }),
                  let plan = space.activePlan, !plan.steps.isEmpty,
                  plan.steps.allSatisfy({ $0.status == .done }) else {
                return fail(requestID, "请先完成方案中的整理步骤")
            }
            guard let preview = Self.thumbnailDataURL(for: image) else {
                return fail(requestID, "照片预览生成失败，请重试")
            }
            pendingProofImage = (image, space.id, plan.id)
            respond(requestID, data: ["preview": preview])
        }

        private func finishPlan(with image: UIImage) -> Bool {
            guard let space = viewModel.spaces.first(where: { $0.id == viewModel.selectedSpaceID }),
                  let plan = space.activePlan, plan.steps.allSatisfy({ $0.status == .done }) else {
                viewModel.showMessage("请先完成方案中的整理步骤，再保存完成照。")
                return false
            }
            return viewModel.finishActivePlan(afterImage: image)
        }

        func stopCaptureWork() {
            cancelDisorderAssessment()
            pendingProofImage = nil
            cancelImageGeneration()
            scanSessionGeneration += 1
            viewModel.cancelScanWork()
            if !pendingRequestID.isEmpty { cancelCapture() }
            scanQueueTask?.cancel()
            scanQueueTask = nil
            scanQueueTaskID = UUID()
            scanQueueFinished = true
            photoScanResults = [:]
            photoScanErrors = [:]
            stopARScan()
            CameraPreviewOverlay.shared.disarm()
            CameraEngine.shared.stop()
        }

        private func restoreImagePreview(_ payload: [String: Any], requestID: String) {
            guard let (sourceImage, spaceID) = selectedBeforeImage(),
                  let planID = (payload["planID"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !planID.isEmpty,
                  let imageData = Self.imageGenerationJPEGData(for: sourceImage) else {
                return respond(requestID, data: ["available": false])
            }
            let manager = ImageGenerationManager.shared
            let cacheID = "\(spaceID.uuidString)-\(planID)"
            let prompt = imageGenerationPrompt(payload: payload)
            guard let outputURL = manager.cachedPreview(cacheID: cacheID, imageData: imageData, prompt: prompt),
                  let outputImage = UIImage(contentsOfFile: outputURL.path),
                  let preview = Self.thumbnailDataURL(for: outputImage, width: 900) else {
                return respond(requestID, data: ["available": false])
            }
            respond(requestID, data: [
                "available": true,
                "preview": preview,
                "cacheID": outputURL.deletingPathExtension().lastPathComponent,
                "model": manager.settings.model,
                "endpointHost": manager.settings.validatedEndpoint?.host ?? "",
            ])
        }

        private func generateImagePreview(_ payload: [String: Any], requestID: String) async {
            cancelImageGeneration()
            let token = UUID()
            imageGenerationToken = token
            let manager = ImageGenerationManager.shared
            guard let (originalImage, requestedSpaceID) = selectedBeforeImage(),
                  let originalImageData = Self.imageGenerationJPEGData(for: originalImage) else {
                return fail(requestID, ImageGenerationError.invalidInput.localizedDescription)
            }
            let originalPrompt = imageGenerationPrompt(payload: payload)
            let rawPlanID = (payload["planID"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            if rawPlanID?.isEmpty == false, let (sourceImage, spaceID) = selectedBeforeImage(),
               let imageData = Self.imageGenerationJPEGData(for: sourceImage) {
                let cacheID = "\(spaceID.uuidString)-\(rawPlanID!)"
                let prompt = imageGenerationPrompt(payload: payload)
                if let cachedURL = manager.cachedPreview(cacheID: cacheID, imageData: imageData, prompt: prompt),
                   let cachedImage = UIImage(contentsOfFile: cachedURL.path),
                   let preview = Self.thumbnailDataURL(for: cachedImage, width: 900) {
                    return respond(requestID, data: [
                        "preview": preview,
                        "cacheID": cachedURL.deletingPathExtension().lastPathComponent,
                        "provider": manager.settings.provider,
                        "model": manager.settings.model,
                        "endpointHost": manager.settings.validatedEndpoint?.host ?? "",
                        "cached": true,
                    ])
                }
            }
            let validationSettings = viewModel.llmSettings
            guard validationSettings.canRequestVision else {
                return fail(requestID, ImageGenerationError.fidelityUnverified.localizedDescription)
            }
            let status = manager.statusObject()
            guard status["configured"] as? Bool == true else {
                return fail(requestID, ImageGenerationError.notConfigured.localizedDescription)
            }
            guard await requestImageUploadConsentIfNeeded(), imageGenerationToken == token else {
                return fail(requestID, "未上传照片，仍可继续使用本地整理方案。")
            }
            guard requestedSpaceID == viewModel.selectedSpaceID, validationSettings == viewModel.llmSettings else {
                return fail(requestID, "空间已改变，未上传照片，请返回空间页重试。")
            }
            let spaceID = requestedSpaceID
            let imageData = originalImageData
            let prompt = originalPrompt
            let cacheID = "\(spaceID.uuidString)-\((rawPlanID?.isEmpty == false ? rawPlanID : nil) ?? "plan")"
            var focusRegion: ImagePreviewRegion?
            if let value = payload["focusRect"] {
                guard let raw = value as? [String: Double], let x = raw["x"], let y = raw["y"], let width = raw["width"], let height = raw["height"],
                      let valid = ImagePreviewRegion(x: x, y: y, width: width, height: height) else {
                    return fail(requestID, "效果图分区范围无效，请重新选择区域。")
                }
                focusRegion = valid
            }
            let region = focusRegion
            let task = Task.detached(priority: .userInitiated) {
                try await manager.generatePreview(imageData: imageData, prompt: prompt, cacheID: cacheID, focusRegion: region) { generatedData in
                    try Task.checkCancellation()
                    guard let source = UIImage(data: imageData), let generated = UIImage(data: generatedData) else {
                        throw ImageGenerationError.invalidResponse
                    }
                    let assessment: PreviewFidelityAssessment
                    do {
                        assessment = try await CloudVisionRecognitionService().reviewPreview(source: source, preview: generated, settings: validationSettings)
                    } catch is CancellationError { throw CancellationError() }
                    catch { throw ImageGenerationError.fidelityUnverified }
                    switch assessment.verdict {
                    case .pass: return
                    case .fail: throw ImageGenerationError.fidelityFailed
                    case .uncertain: throw ImageGenerationError.fidelityUnverified
                    }
                }
            }
            imageGenerationTask = task
            defer {
                if imageGenerationToken == token { imageGenerationTask = nil }
            }

            do {
                let outputURL = try await task.value
                guard imageGenerationToken == token, !task.isCancelled, spaceID == viewModel.selectedSpaceID,
                      let outputImage = UIImage(contentsOfFile: outputURL.path),
                      let preview = Self.thumbnailDataURL(for: outputImage, width: 900) else {
                    return fail(requestID, "效果图生成已取消。")
                }
                let settings = manager.settings
                respond(requestID, data: [
                    "preview": preview,
                    "cacheID": outputURL.deletingPathExtension().lastPathComponent,
                    "provider": settings.provider,
                    "model": settings.model,
                    "endpointHost": settings.validatedEndpoint?.host ?? "",
                ])
            } catch is CancellationError {
                fail(requestID, "效果图生成已取消。")
            } catch {
                fail(requestID, (error as? ImageGenerationError)?.localizedDescription ?? "效果图生成失败，当前仍可继续使用本地整理方案。")
            }
        }

        private func cancelImageGeneration() {
            imageGenerationToken = UUID()
            imageGenerationTask?.cancel()
            imageGenerationTask = nil
            imageConsentAlert?.dismiss(animated: true)
            resolveImageUploadConsent(false)
        }

        private func requestImageUploadConsentIfNeeded() async -> Bool {
            let manager = ImageGenerationManager.shared
            if manager.hasConsentForCurrentEndpoint { return true }
            guard let host = manager.settings.validatedEndpoint?.host,
                  let presenter = topViewController() else { return false }

            return await withCheckedContinuation { continuation in
                pendingImageConsent = { allowed in continuation.resume(returning: allowed) }
                let alert = UIAlertController(
                    title: "生成整理效果图",
                    message: "将当前空间照片和整理目标发送到 \(host) 生成效果图。照片可能包含个人物品，请确认是否上传。",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "暂不上传", style: .cancel) { [weak self] _ in
                    self?.resolveImageUploadConsent(false)
                })
                alert.addAction(UIAlertAction(title: "同意并生成", style: .default) { [weak self] _ in
                    manager.grantConsentForCurrentEndpoint()
                    self?.resolveImageUploadConsent(true)
                })
                imageConsentAlert = alert
                presenter.present(alert, animated: true)
            }
        }

        private func resolveImageUploadConsent(_ allowed: Bool) {
            let completion = pendingImageConsent
            pendingImageConsent = nil
            imageConsentAlert = nil
            completion?(allowed)
        }

        private func cancelDisorderAssessment() {
            disorderToken = UUID()
            disorderTask?.cancel()
            disorderTask = nil
        }

        private func analyzeDisorder(_ payload: [String: Any], requestID: String) async {
            guard let spaceID = uuid(payload["spaceID"]), spaceID == viewModel.selectedSpaceID,
                  let source = viewModel.capturedImage, !photoScanResults.isEmpty else {
                return fail(requestID, "本次拍摄照片已失效，请重新提交照片后评估")
            }
            let settings = viewModel.llmSettings
            guard settings.canRequestVision else {
                return fail(requestID, "视觉评估不可用：请在AI设置启用视觉服务并同意照片上传，也可跳过评估")
            }
            cancelDisorderAssessment()
            let token = disorderToken
            let generation = scanSessionGeneration
            let task = Task { try await CloudVisionRecognitionService().assessDisorder(image: source, settings: settings) }
            disorderTask = task
            defer { if disorderToken == token { disorderTask = nil } }
            do {
                let result = try await task.value
                guard !Task.isCancelled, token == disorderToken, generation == scanSessionGeneration,
                      spaceID == viewModel.selectedSpaceID, settings == viewModel.llmSettings, viewModel.capturedImage === source else {
                    return fail(requestID, "评估已取消或照片/设置已改变，请重新评估")
                }
                let data = try JSONEncoder().encode(result)
                var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
                object["sourceSpaceID"] = spaceID.uuidString
                object["sourceDescription"] = "本轮最后一张照片"
                object["sourcePreview"] = Self.thumbnailDataURL(for: source)
                respond(requestID, data: object)
            } catch {
                if token != disorderToken || task.isCancelled { return fail(requestID, "视觉评估已取消") }
                fail(requestID, "视觉评估未完成：\(error.localizedDescription)，可以重试或跳过")
            }
        }

        private func selectedBeforeImage() -> (UIImage, UUID)? {
            guard let space = viewModel.spaces.first(where: { $0.id == viewModel.selectedSpaceID }) else { return nil }
            if let url = viewModel.imageURL(for: space.beforeImageName),
               let image = UIImage(contentsOfFile: url.path) {
                return (image, space.id)
            }
            if let assetName = space.beforeAssetName, let image = UIImage(named: assetName) {
                return (image, space.id)
            }
            if let image = viewModel.capturedImage { return (image, space.id) }
            return nil
        }

        private static func imageGenerationJPEGData(for image: UIImage, maxDimension: CGFloat = 1_536) -> Data? {
            let largestDimension = max(image.size.width, image.size.height)
            let scale = largestDimension > maxDimension ? maxDimension / largestDimension : 1
            let targetSize = CGSize(
                width: max(1, (image.size.width * scale).rounded()),
                height: max(1, (image.size.height * scale).rounded())
            )
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = true
            let normalized = UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: targetSize))
            }
            return normalized.jpegData(compressionQuality: 0.84)
        }

        private func imageGenerationPrompt(payload: [String: Any]) -> String {
            let space = viewModel.spaces.first(where: { $0.id == viewModel.selectedSpaceID })
            let regionIdentity: String
            if let rect = payload["focusRect"] as? [String: Double],
               let data = try? JSONSerialization.data(withJSONObject: rect, options: [.sortedKeys]),
               let text = String(data: data, encoding: .utf8) {
                regionIdentity = "\n所选照片范围：\(text)"
            } else { regionIdentity = "" }
            return StoragePreviewPrompt.make(
                planName: payload["planName"] as? String ?? "实用整理",
                goal: payload["goal"] as? String ?? "降低视觉杂乱、恢复可用面积",
                changes: payload["changes"] as? [String] ?? [],
                itemNames: (space?.detectedItems ?? viewModel.scannedItems).filter(\.isSelected).map(\.name),
                focusZone: payload["focusZone"] as? String ?? "") + "\n效果图协议：v3，保持画幅；分区预览由原图与选区合成，区域外使用原图；须完成原图与结果图的双图保真复核后才能保存。" + regionIdentity
        }

        private func saveItems(_ payload: [String: Any], requestID: String) {
            guard let rawItems = payload["items"] as? [[String: Any]] else { return fail(requestID, "缺少物品数据") }
            let existing = Dictionary(uniqueKeysWithValues: viewModel.scannedItems.map { ($0.id, $0) })
            var items: [DetectedItem] = []
            for raw in rawItems {
                guard let rawCategory = raw["category"] as? String,
                      let category = ItemCategory(webValue: rawCategory) else { return fail(requestID, "物品类别无效") }
                let id = uuid(raw["id"]) ?? UUID()
                var item = existing[id] ?? DetectedItem(name: raw["name"] as? String ?? "未命名物品", category: category, confidence: raw["confidence"] as? Double ?? 1)
                item.name = raw["name"] as? String ?? item.name; item.category = category
                item.suggestedZone = raw["suggestedZone"] as? String ?? category.suggestedZone
                item.isSelected = raw["isSelected"] as? Bool ?? true
                items.append(item)
            }
            guard viewModel.replaceScannedItems(items) else { return fail(requestID, viewModel.message ?? "物品保存失败") }
            respondWithState(requestID)
        }

        private func generatePlan(_ payload: [String: Any], requestID: String) async {
            viewModel.planningGoal = payload["goal"] as? String ?? ""; viewModel.focusZone = payload["focusZone"] as? String ?? ""
            if let style = StorageStyle(rawValue: payload["style"] as? String ?? "") { viewModel.selectedStyle = style }
            if let minutes = payload["minutes"] as? Int, let budget = TimeBudget(rawValue: minutes) { viewModel.selectedTimeBudget = budget }
            guard await viewModel.makePlanFromScanUsingCloudIfAvailable(navigateToSpace: false) else { return fail(requestID, viewModel.message ?? "方案生成失败") }
            respondWithState(requestID)
        }

        private func sendChat(_ payload: [String: Any], requestID: String) async {
            guard let message = payload["message"] as? String, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return fail(requestID, "消息不能为空")
            }
            let history = (payload["history"] as? [[String: Any]] ?? []).compactMap { item -> [String: String]? in
                guard let role = item["role"] as? String, let text = item["text"] as? String else { return nil }
                return ["role": role, "text": text]
            }
            do {
                let planName = (payload["planName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                let reply = try await viewModel.sendChatMessage(message: message, history: history, planName: planName)
                respond(requestID, data: ["reply": reply, "mode": "cloud"])
            } catch {
                fail(requestID, error.localizedDescription)
            }
        }

        private func mutateCommunity(_ payload: [String: Any], requestID: String, action: (UUID) -> Bool) {
            guard let id = uuid(payload["id"]) else { return fail(requestID, "案例 ID 无效") }
            guard action(id) else { return fail(requestID, viewModel.message ?? "社区操作保存失败，请重试") }
            respondWithState(requestID)
        }

        // MARK: - AR 实时扫描（网页用）

        /// 网页 AR 实时通道：这一层只负责"喂帧 + 累积结果"，
        /// 识别本体沿用原生那套已验证的本地实时管线（`RecognitionRouter.scanLiveImage`）。
        private struct AREntry {
            var id: UUID
            var name: String
            var confidence: Double
            var hint: ARHint
            var lastSeen: Date
        }

        private var arEntries: [AREntry] = []
        private var arRecognizing = false
        private var arPendingFrame: UIImage? = nil
        private var arSessionGeneration = 0
        private var arStartedEngine = false
        private let arPalette = ["#FA883A", "#7FA8C9", "#8B6F47", "#7BB89A", "#A8B8CC", "#E8B894", "#C98B8B", "#B4C7DC"]

        private func startARScan(requestID: String) async {
            let engine = CameraEngine.shared
            // AR 是连续识别，必须自己把相机跑起来（页面可能还没起画面）。
            if !engine.isRunning {
                arStartedEngine = true
                await engine.start()
                _ = await engine.waitUntilReady(timeout: 2)
            }
            guard engine.isRunning else {
                let reason = engine.permissionDenied ? "没有相机权限：去「设置 → 灵爪收纳」里打开相机" : "相机还没准备好，稍等一下再试"
                return fail(requestID, reason)
            }
            arEntries = []
            arRecognizing = false
            arPendingFrame = nil
            arSessionGeneration += 1
            let generation = arSessionGeneration
            // 画面喂得快一点，标签才跟得上移动；识别慢的帧会被下面的"最新帧优先"丢掉。
            engine.liveFrameInterval = 0.22
            engine.onLiveFrame = { [weak self] image in
                guard let self else { return }
                self.arPendingFrame = image
                self.pumpARFrame(generation: generation)
            }
            respond(requestID, data: ["ok": true])
        }

        /// 只处理最新一帧：识别期间新来的旧帧直接作废，
        /// 这样气泡永远贴着"当前"画面，不会因为排队结果滞后半拍。
        private func pumpARFrame(generation: Int) {
            guard generation == arSessionGeneration, !arRecognizing, let image = arPendingFrame else { return }
            arPendingFrame = nil
            arRecognizing = true
            Task {
                let results = await RecognitionRouter.shared.scanLiveImage(image)
                guard generation == self.arSessionGeneration else {
                    self.arRecognizing = false
                    return
                }
                self.arRecognizing = false
                self.mergeARResults(results)
                // 识别这一帧的时间里又来了新画面：立刻接着跑，不等下一个相机帧。
                self.pumpARFrame(generation: generation)
            }
        }

        /// 跨帧累物：同名保留置信度最高的一帧、位置跟着最新一帧走，9 秒没再出现才撤掉
        /// （撤得太快会让气泡一闪一闪，看起来像"扫不出来"）。
        private func mergeARResults(_ incoming: [DetectedItem]) {
            for item in incoming {
                guard let hint = item.arHint else { continue }
                if let index = arEntries.firstIndex(where: {
                    $0.name == item.name && Self.hintIoU($0.hint, hint) >= 0.10
                }) {
                    arEntries[index].confidence = max(arEntries[index].confidence, item.confidence)
                    arEntries[index].hint = hint
                    arEntries[index].lastSeen = Date()
                } else {
                    arEntries.append(AREntry(id: item.id, name: item.name, confidence: item.confidence, hint: hint, lastSeen: Date()))
                }
            }
            let cutoff = Date().addingTimeInterval(-9.0)
            arEntries = Array(arEntries.filter { $0.lastSeen > cutoff }.sorted { $0.confidence > $1.confidence }.prefix(8))
        }

        private func pollARScan(requestID: String) {
            let items: [[String: Any]] = arEntries.enumerated().map { index, entry in
                var dict: [String: Any] = [
                    "name": entry.name,
                    "confidence": entry.confidence,
                    "color": arPalette[index % arPalette.count],
                ]
                let hint = entry.hint
                dict["hint"] = ["x": hint.x, "y": hint.y, "width": hint.width, "height": hint.height]
                return dict
            }
            respond(requestID, data: ["items": items, "count": items.count])
        }

        private func stopARScan() {
            arSessionGeneration += 1
            arPendingFrame = nil
            CameraEngine.shared.onLiveFrame = nil
            if arStartedEngine {
                CameraEngine.shared.stop()
                arStartedEngine = false
            }
            arEntries = []
            arRecognizing = false
        }

        private static func hintIoU(_ lhs: ARHint, _ rhs: ARHint) -> Double {
            let lx = lhs.x - lhs.width / 2, ly = lhs.y - lhs.height / 2
            let rx = rhs.x - rhs.width / 2, ry = rhs.y - rhs.height / 2
            let ix = max(0, min(lx + lhs.width, rx + rhs.width) - max(lx, rx))
            let iy = max(0, min(ly + lhs.height, ry + rhs.height) - max(ly, ry))
            let intersection = ix * iy
            let union = lhs.width * lhs.height + rhs.width * rhs.height - intersection
            return union > 0 ? intersection / union : 0
        }

        private func stateObject() -> Any {
            struct ProfileStats: Encodable {
                let trackedItemCount: Int
                let organizedSpaceCount: Int
            }
            struct WebAchievement: Encodable {
                let id: UUID
                let title: String
                let subtitle: String
                let iconName: String
                let isUnlocked: Bool
            }
            struct State: Encodable {
                let spaces: [StorageSpace]; let selectedSpaceID: UUID?; let scannedItems: [DetectedItem]
                let achievements: [WebAchievement]; let communityCases: [CommunityCase]; let comments: [UUID: [CommunityComment]]
                let liked: [UUID]; let favorites: [UUID]; let followedAuthors: [String]; let schedules: [ScheduleItem]; let message: String?
                let scanDiagnostics: [String: String]
                let profileStats: ProfileStats
                let isPresentationMode: Bool
            }
            var diagnostics = RecognitionRouter.shared.diagnostics
            diagnostics["modelCount"] = "\(YOLOSegmentationScanService.loadedModelCount)"
            diagnostics["models"] = YOLOSegmentationScanService.loadedModelNames.joined(separator: "、")
            diagnostics["cloudReady"] = viewModel.llmSettings.canRequestVision ? "yes" : "no"
            let value = State(spaces: viewModel.spaces, selectedSpaceID: viewModel.selectedSpaceID, scannedItems: viewModel.scannedItems,
                achievements: viewModel.achievements.map { WebAchievement(id: $0.id, title: $0.title, subtitle: $0.subtitle, iconName: $0.iconName, isUnlocked: viewModel.isAchievementUnlocked($0)) }, communityCases: viewModel.communityCases, comments: viewModel.communityComments,
                liked: Array(viewModel.likedCommunityCaseIDs), favorites: Array(viewModel.favoriteCommunityCaseIDs),
                followedAuthors: Array(viewModel.followedCommunityAuthors), schedules: viewModel.scheduleItems, message: viewModel.message,
                scanDiagnostics: diagnostics,
                profileStats: ProfileStats(trackedItemCount: viewModel.catalogItems.count, organizedSpaceCount: viewModel.spaces.filter { !$0.completedPlans.isEmpty }.count),
                isPresentationMode: viewModel.isPresentationMode)
            let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
            guard let data = try? encoder.encode(value), let object = try? JSONSerialization.jsonObject(with: data) else { return [:] }
            return object
        }

        private func respondWithState(_ id: String) { respond(id, data: stateObject()) }
        private func respond(_ id: String, data: Any) { emit(["requestId": id, "status": "success", "data": data]) }
        private func fail(_ id: String, _ error: String) { emit(["requestId": id, "status": "error", "error": error]) }
        private func cancelCapture() { emit(["requestId": pendingRequestID, "status": "cancelled"]); pendingRequestID = ""; pendingCaptureID = nil }
        private func failCapture(_ error: String) {
            let requestID = pendingRequestID
            pendingRequestID = ""
            pendingCaptureID = nil
            fail(requestID, error)
        }
        private func uuid(_ value: Any?) -> UUID? { (value as? String).flatMap(UUID.init(uuidString:)) }
        private func emit(_ response: [String: Any]) {
            guard JSONSerialization.isValidJSONObject(response), let data = try? JSONSerialization.data(withJSONObject: response),
                  let json = String(data: data, encoding: .utf8) else { return }
            webView?.evaluateJavaScript("window.__smartPawReceive?.(\(json));")
        }
        private func topViewController() -> UIViewController? {
            guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
                  let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else { return nil }
            var current = root; while let presented = current.presentedViewController { current = presented }; return current
        }
    }

    fileprivate static func loadBundle(in webView: WKWebView) {
        // 注意：CSS 可能是可选的 —— 打包一旦把样式并进 JS（现在的构建就是这样），
        // assets 里就不会再有 .css 文件。以前这里把 css 写成必需条件，缺.css 就直接 return，
        // 结果整页不加载、只剩白屏。现在允许为空，样式由 JS 自己注入。
        // 从 Vite 的 index.html 读取入口文件名，避免旧构建资源仍在 Bundle 中时随机加载错版。
        let assetURLs = Bundle.main.urls(forResourcesWithExtension: "js", subdirectory: "FigmaMakeLatestWeb/assets")
        let htmlURL = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "FigmaMakeLatestWeb")
        let html = htmlURL.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
        let entryPattern = #"src="/assets/(index-[^"]+\.js)""#
        let entryName: String? = html.range(of: entryPattern, options: .regularExpression).flatMap { range in
            let entry = String(html[range])
            let prefix = "src=\"/assets/"
            guard entry.hasPrefix(prefix), entry.hasSuffix("\"") else { return nil }
            return String(entry.dropFirst(prefix.count).dropLast())
        }
        let jsURL = assetURLs?.first(where: { $0.lastPathComponent == entryName })
            ?? assetURLs?.first(where: { $0.lastPathComponent.hasPrefix("index-") })
            ?? assetURLs?.first
        guard let base = Bundle.main.url(forResource: "FigmaMakeLatestWeb", withExtension: nil),
              let jsURL,
              let js = try? String(contentsOf: jsURL, encoding: .utf8) else { return }
        let css = Bundle.main.urls(forResourcesWithExtension: "css", subdirectory: "FigmaMakeLatestWeb/assets")?.first
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
        // 设计稿画布是 390×844。直接让网页拉伸铺满会把布局拉变形（拍摄页取景区
        // 变高、dock 沉底），所以这里固定 root 为设计稿尺寸，再整体等比缩放到屏宽
        //（contain 模式，确保底部导航和安全区始终完整可见），保证和 Figma 里的比例一致。
        webView.loadHTMLString("""
        <!doctype html><html lang="zh-CN"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover"><style>html,body{width:100%;height:100%;margin:0;overflow:hidden;background:#EDE5DA}#root{position:absolute;top:0;left:0;width:390px;height:844px;transform-origin:top left;overflow:hidden}</style><style>\(css)</style></head><body><div id="root"></div><script>\(js)</script><script>(function(){function fit(){var s=Math.min(window.innerWidth/390,window.innerHeight/844);var r=document.getElementById('root');if(r)r.style.transform='scale('+s+')';}window.addEventListener('resize',fit);fit();})();</script></body></html>
        """, baseURL: base)
    }
}

extension CurrentFigmaMakeWebView.Coordinator: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        if url.isFileURL || url.absoluteString == "about:blank" {
            decisionHandler(.allow)
        } else {
            // 外部网页交给系统浏览器，避免将原生桥接暴露给远程页面。
            decisionHandler(.cancel)
            if navigationAction.navigationType == .linkActivated,
               ["https", "mailto"].contains(url.scheme?.lowercased() ?? "") {
                UIApplication.shared.open(url)
            }
        }
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        stopCaptureWork()
        CurrentFigmaMakeWebView.loadBundle(in: webView)
    }

    // 网页加载完成 → 通知 RootView 把启动封面淡出。
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        NotificationCenter.default.post(name: .smartPawWebReady, object: nil)
    }
}
