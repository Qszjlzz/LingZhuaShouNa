import SwiftUI
import AVFoundation
import WebKit

/// 把相机实时画面垫在 WebView 底下，让网页里的拍摄页看起来自带取景框。
///
/// 网页把预览区的位置告诉原生，原生在 WebView 下方（belowSubview）放一块
/// 实时画面；网页同时把自己的占位图和背景改成透明，画面就透上来了。
/// 这样顶栏、快门按钮等网页元素仍然浮在画面之上，点快门直接原地拍照，
/// 不再跳出任何相机页面。
///
/// 画面来源固定是 `CameraEngine.shared`（全 App 唯一的 session）。
/// 以前这里自己 new 了一个相机控制器，结果是两个 AVCaptureSession 并存，
/// 互相抢资源导致卡顿和偶发闪退。
final class CameraPreviewOverlay {
    static let shared = CameraPreviewOverlay()

    private weak var host: WKWebView?
    private var surface: PreviewSurfaceView?
    /// 这次是不是我们把它开起来的。如果进来之前扫描页已经在用，
    /// 就别抢着关掉人家的 session。
    private var startedByOverlay = false

    var isReady: Bool { CameraEngine.shared.isReady }

    @MainActor
    func start(in webView: WKWebView, frame: CGRect) async -> Bool {
        let engine = CameraEngine.shared
        let alreadyRunning = engine.isRunning

        await engine.start()
        // start() 里 isReady 是异步回主线程更新的，直接读会读到 false，
        // 那样网页就误以为"没有相机"退回去弹原生页了，所以这里要等它就绪。
        guard await engine.waitUntilReady() else { return false }

        startedByOverlay = !alreadyRunning

        // 重复 start（比如页面重新挂载）时先清掉上一块画面，避免叠层。
        surface?.removeFromSuperview()

        host = webView
        let view = PreviewSurfaceView(session: engine.session)
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

        // 还原 WebView 的透明状态，否则离开拍摄页后整块内容一直是透的。
        if let webView = host {
            webView.backgroundColor = nil
            webView.scrollView.backgroundColor = nil
            webView.isOpaque = false
        }
        host = nil

        if startedByOverlay {
            startedByOverlay = false
            CameraEngine.shared.stop()
        }
    }

    /// 原地抓一帧。相机不可用时返回 nil，网页会回退到选图。
    ///
    /// 连拍安全：请求统一进 `CameraEngine` 的等待队列，每张都有自己的回调，
    /// 不会互相覆盖；超过一定时间还没回包会按失败收尾，不会让网页干等到超时。
    @MainActor
    func capture() async -> UIImage? {
        let engine = CameraEngine.shared
        guard engine.isReady else { return nil }
        return await engine.capturePhoto()
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
