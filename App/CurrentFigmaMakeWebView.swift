import SwiftUI
import WebKit
import UIKit
import PhotosUI

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
        context.coordinator.webView = webView
        loadBundle(in: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.viewModel = viewModel
        guard webView.url == nil else { return }
        loadBundle(in: webView)
    }

    @MainActor
    final class Coordinator: NSObject, WKScriptMessageHandler, UIImagePickerControllerDelegate,
        UINavigationControllerDelegate, PHPickerViewControllerDelegate {
        weak var webView: WKWebView?
        var viewModel: AppViewModel
        private var pendingRequestID = ""
        private var capturePurpose = "scan"

        init(viewModel: AppViewModel) { self.viewModel = viewModel }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let request = message.body as? [String: Any],
                  let requestID = request["requestId"] as? String,
                  let command = request["command"] as? String else { return }
            let payload = request["payload"] as? [String: Any] ?? [:]
            Task { await handle(requestID: requestID, command: command, payload: payload) }
        }

        private func handle(requestID: String, command: String, payload: [String: Any]) async {
            switch command {
            case "state.get": respond(requestID, data: stateObject())
            case "llm.settings.get": respond(requestID, data: ["isEnabled": viewModel.llmSettings.isEnabled, "endpoint": viewModel.llmSettings.endpoint, "model": viewModel.llmSettings.model, "hasAPIKey": !viewModel.llmSettings.apiKey.isEmpty])
            case "llm.settings.save":
                let settings = LLMSettings(isEnabled: payload["isEnabled"] as? Bool ?? false, endpoint: payload["endpoint"] as? String ?? LLMSettings.default.endpoint, apiKey: payload["apiKey"] as? String ?? viewModel.llmSettings.apiKey, model: payload["model"] as? String ?? LLMSettings.default.model)
                guard viewModel.saveLLMSettings(settings) else { return fail(requestID, viewModel.message ?? "AI 设置保存失败") }
                respond(requestID, data: ["saved": true])
            case "llm.test":
                let settings = LLMSettings(isEnabled: true, endpoint: payload["endpoint"] as? String ?? viewModel.llmSettings.endpoint, apiKey: payload["apiKey"] as? String ?? viewModel.llmSettings.apiKey, model: payload["model"] as? String ?? viewModel.llmSettings.model)
                await viewModel.testLLMConnection(settings)
                respond(requestID, data: ["state": String(describing: viewModel.llmConnectionState)])
            case "capture.open": openCapture(requestID: requestID, payload: payload)
            case "scan.open": openScanStudio(requestID: requestID, payload: payload)
            case "camera.preview.start": await startInlinePreview(requestID: requestID, payload: payload)
            case "camera.preview.frame": updateInlinePreviewFrame(payload: payload); respond(requestID, data: ["ok": true])
            case "camera.preview.stop": CameraPreviewOverlay.shared.stop(); respond(requestID, data: ["ok": true])
            case "camera.capture": await captureInline(requestID: requestID)
            case "space.select":
                guard let id = uuid(payload["id"]) else { return fail(requestID, "空间 ID 无效") }
                viewModel.selectSpace(id); respondWithState(requestID)
            case "space.add":
                guard let id = viewModel.addSpace(name: payload["name"] as? String ?? "新空间") else { return fail(requestID, "空间名称不能为空") }
                respond(requestID, data: ["id": id.uuidString, "state": stateObject()])
            case "space.rename":
                guard let id = uuid(payload["id"]) else { return fail(requestID, "空间 ID 无效") }
                viewModel.renameSpace(id, name: payload["name"] as? String ?? ""); respondWithState(requestID)
            case "space.delete":
                guard let id = uuid(payload["id"]) else { return fail(requestID, "空间 ID 无效") }
                viewModel.deleteSpace(id); respondWithState(requestID)
            case "items.save": saveItems(payload, requestID: requestID)
            case "item.add":
                let category = ItemCategory(rawValue: payload["category"] as? String ?? "") ?? .tools
                viewModel.addManualItem(name: payload["name"] as? String ?? "", category: category, forScan: true)
                respondWithState(requestID)
            case "item.delete":
                guard let id = uuid(payload["id"]) else { return fail(requestID, "物品 ID 无效") }
                viewModel.removeCatalogItem(id); respondWithState(requestID)
            case "plan.generate": await generatePlan(payload, requestID: requestID)
            case "chat.send": await sendChat(payload, requestID: requestID)
            case "plan.step.complete":
                guard let id = uuid(payload["id"]) else { return fail(requestID, "步骤 ID 无效") }
                viewModel.completeStep(id); respondWithState(requestID)
            case "community.like": mutateCommunity(payload, requestID: requestID, action: viewModel.toggleCommunityLike)
            case "community.favorite": mutateCommunity(payload, requestID: requestID, action: viewModel.toggleCommunityFavorite)
            case "community.follow": viewModel.toggleCommunityFollow(author: payload["author"] as? String ?? ""); respondWithState(requestID)
            case "community.comment":
                guard let id = uuid(payload["id"]) else { return fail(requestID, "案例 ID 无效") }
                viewModel.addCommunityComment(to: id, body: payload["body"] as? String ?? ""); respondWithState(requestID)
            case "community.shareCompletion": viewModel.shareLatestCompletion(); respondWithState(requestID)
            case "schedule.add":
                viewModel.addScheduleItem(title: payload["title"] as? String ?? "整理复盘", dueText: payload["dueText"] as? String ?? "明天", note: payload["note"] as? String ?? "")
                respondWithState(requestID)
            case "schedule.toggle":
                guard let id = uuid(payload["id"]) else { return fail(requestID, "日程 ID 无效") }
                viewModel.toggleScheduleItem(id); respondWithState(requestID)
            case "schedule.delete":
                guard let id = uuid(payload["id"]) else { return fail(requestID, "日程 ID 无效") }
                viewModel.deleteScheduleItem(id); respondWithState(requestID)
            default: fail(requestID, "暂不支持命令：\(command)")
            }
        }

        private func openCapture(requestID: String, payload: [String: Any]) {
            pendingRequestID = requestID
            capturePurpose = payload["purpose"] as? String ?? "scan"
            if payload["source"] as? String == "camera", UIImagePickerController.isSourceTypeAvailable(.camera) {
                presentCameraCapture()
            } else {
                var config = PHPickerConfiguration(photoLibrary: .shared())
                config.filter = .images; config.selectionLimit = capturePurpose == "scan" ? 6 : 1
                let picker = PHPickerViewController(configuration: config); picker.delegate = self
                topViewController()?.present(picker, animated: true)
            }
        }

        /// 拍摄统一走原生页：画面是原生的，照片留在原生侧，
        /// 只把 240px 缩略图回给网页做展示，避免大图 base64 撑爆 WebView。
        private func openScanStudio(requestID: String, payload: [String: Any]) {
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
            Task {
                await viewModel.scanImages(result.images)
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
            respond(requestID, data: ["ok": ok])
        }

        private func updateInlinePreviewFrame(payload: [String: Any]) {
            guard let x = payload["x"] as? Double, let y = payload["y"] as? Double,
                  let w = payload["width"] as? Double, let h = payload["height"] as? Double else { return }
            CameraPreviewOverlay.shared.updateFrame(CGRect(x: x, y: y, width: w, height: h))
        }

        /// 原地拍一张：不弹任何界面，拍完直接把图交给识别流程。
        private func captureInline(requestID: String) async {
            guard let image = await CameraPreviewOverlay.shared.capture() else {
                return fail(requestID, "相机不可用")
            }
            pendingRequestID = requestID
            consume(images: [image])
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
            guard let image = info[.originalImage] as? UIImage else { return fail(pendingRequestID, "没有取得照片") }
            consume(images: [image])
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { picker.dismiss(animated: true); cancelCapture() }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard !results.isEmpty else { return cancelCapture() }
            Task {
                var images: [UIImage] = []
                for result in results where result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                    if let image = await loadImage(from: result.itemProvider) { images.append(image) }
                }
                guard !images.isEmpty else { return fail(pendingRequestID, "所选照片无法读取") }
                consume(images: images)
            }
        }

        /// 网页只需要一张能看的小图。原图留在原生侧做识别，不跨桥回传。
        private static func thumbnailDataURL(for image: UIImage, width: CGFloat = 240) -> String? {
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
                provider.loadObject(ofClass: UIImage.self) { object, _ in
                    continuation.resume(returning: object as? UIImage)
                }
            }
        }

        private func consume(images: [UIImage]) {
            let requestID = pendingRequestID
            // 只回传小图：网页只做展示，识别用的是原生侧的原图。
            // 之前这里回传全分辨率 JPEG 的 base64，几张连拍就能把 WebView 撑到被系统杀掉。
            let preview = images.first.flatMap { Self.thumbnailDataURL(for: $0) }
            if capturePurpose == "after", let image = images.first {
                viewModel.finishActivePlan(afterImage: image)
                respond(requestID, data: ["preview": preview as Any, "state": stateObject()]); return
            }
            Task {
                await viewModel.scanImages(images)
                respond(requestID, data: ["preview": preview as Any, "state": stateObject()])
            }
        }

        private func saveItems(_ payload: [String: Any], requestID: String) {
            guard let rawItems = payload["items"] as? [[String: Any]] else { return fail(requestID, "缺少物品数据") }
            let existing = Dictionary(uniqueKeysWithValues: viewModel.scannedItems.map { ($0.id, $0) })
            let items = rawItems.compactMap { raw -> DetectedItem? in
                let id = uuid(raw["id"]) ?? UUID(); let category = ItemCategory(rawValue: raw["category"] as? String ?? "") ?? .tools
                var item = existing[id] ?? DetectedItem(name: raw["name"] as? String ?? "未命名物品", category: category, confidence: raw["confidence"] as? Double ?? 1)
                item.name = raw["name"] as? String ?? item.name; item.category = category
                item.suggestedZone = raw["suggestedZone"] as? String ?? category.suggestedZone
                item.isSelected = raw["isSelected"] as? Bool ?? true
                return item
            }
            viewModel.replaceScannedItems(items); respondWithState(requestID)
        }

        private func generatePlan(_ payload: [String: Any], requestID: String) async {
            viewModel.planningGoal = payload["goal"] as? String ?? ""; viewModel.focusZone = payload["focusZone"] as? String ?? ""
            if let style = StorageStyle(rawValue: payload["style"] as? String ?? "") { viewModel.selectedStyle = style }
            if let minutes = payload["minutes"] as? Int, let budget = TimeBudget(rawValue: minutes) { viewModel.selectedTimeBudget = budget }
            await viewModel.makePlanFromScanUsingCloudIfAvailable(navigateToSpace: false); respondWithState(requestID)
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
                let reply = try await viewModel.sendChatMessage(message: message, history: history)
                respond(requestID, data: ["reply": reply, "mode": "cloud"])
            } catch {
                fail(requestID, error.localizedDescription)
            }
        }

        private func mutateCommunity(_ payload: [String: Any], requestID: String, action: (UUID) -> Void) {
            guard let id = uuid(payload["id"]) else { return fail(requestID, "案例 ID 无效") }
            action(id); respondWithState(requestID)
        }

        private func stateObject() -> Any {
            struct State: Encodable {
                let spaces: [StorageSpace]; let selectedSpaceID: UUID?; let scannedItems: [DetectedItem]
                let achievements: [Achievement]; let communityCases: [CommunityCase]; let comments: [UUID: [CommunityComment]]
                let liked: [UUID]; let favorites: [UUID]; let followedAuthors: [String]; let schedules: [ScheduleItem]; let message: String?
            }
            let value = State(spaces: viewModel.spaces, selectedSpaceID: viewModel.selectedSpaceID, scannedItems: viewModel.scannedItems,
                achievements: viewModel.achievements, communityCases: viewModel.communityCases, comments: viewModel.communityComments,
                liked: Array(viewModel.likedCommunityCaseIDs), favorites: Array(viewModel.favoriteCommunityCaseIDs),
                followedAuthors: Array(viewModel.followedCommunityAuthors), schedules: viewModel.scheduleItems, message: viewModel.message)
            let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
            guard let data = try? encoder.encode(value), let object = try? JSONSerialization.jsonObject(with: data) else { return [:] }
            return object
        }

        private func respondWithState(_ id: String) { respond(id, data: stateObject()) }
        private func respond(_ id: String, data: Any) { emit(["requestId": id, "status": "success", "data": data]) }
        private func fail(_ id: String, _ error: String) { emit(["requestId": id, "status": "error", "error": error]) }
        private func cancelCapture() { emit(["requestId": pendingRequestID, "status": "cancelled"]); pendingRequestID = "" }
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

    private func loadBundle(in webView: WKWebView) {
        guard let base = Bundle.main.url(forResource: "FigmaMakeLatestWeb", withExtension: nil),
              let cssURL = Bundle.main.urls(forResourcesWithExtension: "css", subdirectory: "FigmaMakeLatestWeb/assets")?.first,
              let jsURL = Bundle.main.urls(forResourcesWithExtension: "js", subdirectory: "FigmaMakeLatestWeb/assets")?.first,
              let css = try? String(contentsOf: cssURL, encoding: .utf8),
              let js = try? String(contentsOf: jsURL, encoding: .utf8) else { return }
        webView.loadHTMLString("""
        <!doctype html><html lang="zh-CN"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover"><style>html,body,#root{width:100%;height:100%;margin:0;overflow:hidden}body{background:#EDE5DA}</style><style>\(css)</style></head><body><div id="root"></div><script>\(js)</script></body></html>
        """, baseURL: base)
    }
}
