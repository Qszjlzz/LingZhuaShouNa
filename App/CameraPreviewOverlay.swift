import SwiftUI
import AVFoundation
import WebKit

/// 把相机实时画面垫在 WebView 底下，让网页里的拍摄页看起来自带取景框。
///
/// 网页把预览区的位置告诉原生，原生在 WebView 下方（belowSubview）放一块
/// 实时画面；网页同时把自己的占位图和背景改成透明，画面就透上来了。
/// 这样顶栏、快门按钮等网页元素仍然浮在画面之上，点快门直接原地拍照，
/// 不再跳出任何相机页面。
final class CameraPreviewOverlay {
    static let shared = CameraPreviewOverlay()

    private let controller = CameraController()
    private var surface: PreviewSurfaceView?
    private weak var host: WKWebView?

    var isReady: Bool { controller.isReady }

    @MainActor
    func start(in webView: WKWebView, frame: CGRect) async -> Bool {
        await controller.start()
        guard controller.isReady else { return false }

        host = webView
        let view = PreviewSurfaceView(session: controller.session)
        surface = view
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.isOpaque = false

        if let superview = webView.superview {
            superview.insertSubview(view, belowSubview: webView)
            view.frame = webView.convert(frame, to: superview)
        } else {
            webView.insertSubview(view, at: 0)
            view.frame = frame
        }
        return true
    }

    @MainActor
    func updateFrame(_ frame: CGRect) {
        guard let view = surface, let webView = host else { return }
        view.frame = webView.superview.map { webView.convert(frame, to: $0) } ?? frame
    }

    @MainActor
    func stop() {
        surface?.removeFromSuperview()
        surface = nil
        host = nil
        controller.stop()
    }

    /// 原地抓一帧。相机不可用时返回 nil，网页会回退到选图。
    @MainActor
    func capture() async -> UIImage? {
        guard controller.isReady else { return nil }
        return await withCheckedContinuation { continuation in
            controller.capture { continuation.resume(returning: $0) }
        }
    }
}

private final class PreviewSurfaceView: UIView {
    private let previewLayer: AVCaptureVideoPreviewLayer

    init(session: AVCaptureSession) {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        super.init(frame: .zero)
        backgroundColor = .black
        clipsToBounds = true
        previewLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(previewLayer)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }
}
