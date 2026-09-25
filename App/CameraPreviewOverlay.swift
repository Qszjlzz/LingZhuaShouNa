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
    /// 只暖机、还没接管画面的自动收尾任务。
    private var warmTask: Task<Void, Never>?
    /// 用户希望相机保持待命（进后台会临时解除，回前台再恢复）。
    private var wantsArmed = false

    var isReady: Bool { CameraEngine.shared.isReady }

    private init() {
        // App 进后台就把相机真正停掉：后台跑相机既费电又会让系统提示"正在使用相机"。
        let center = NotificationCenter.default
        center.addObserver(forName: UIApplication.didEnterBackgroundNotification,
                           object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.suspendForBackground() }
        }
        center.addObserver(forName: UIApplication.didBecomeActiveNotification,
                           object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.wantsArmed, let host = self.host else { return }
                await self.arm(in: host)
            }
        }
    }

    /// 进后台：记下"本来是待命的"，然后彻底停掉。
    @MainActor
    private func suspendForBackground() {
        let wasArmed = wantsArmed || surface != nil
        disarm()
        wantsArmed = wasArmed
    }

    /// 点击拍摄按钮的瞬间调用：只把摄像头加电跑起来，不显示画面、不改透明。
    ///
    /// 相机硬件加电要几百毫秒，以前这段时间是等网页把拍摄页渲染完才开始算的，
    /// 两段串行所以看起来"要加载"。现在点击即暖机，和网页渲染并行跑，
    /// 等页面挂载好来接管时画面通常已经在了。
    @MainActor
    func warmUp() async {
        warmTask?.cancel()
        let engine = CameraEngine.shared
        if !engine.isRunning { startedByOverlay = true }
        await engine.start()

        // 暖机后如果没人来接管（比如误触、或网页没起来），别让相机一直空转。
        warmTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            guard let self else { return }
            if self.surface == nil { self.stop() }
        }
    }

    // MARK: - 常驻待命（点开拍摄页"零加载"的关键）

    /// App 在前台期间让相机一直跑着：画面层已经铺在 WebView 底下，只是
    /// 透明不可见。这样点拍摄按钮时剩下要做的只有"把 alpha 打开"，
    /// 一帧内出画面，不再有加电和建层的等待。
    ///
    /// 只在用户已经授权过相机时调用 —— 免得刚打开 App 就弹权限框。
    @MainActor
    func armIfAuthorized(in webView: WKWebView) async {
        let engine = CameraEngine.shared
        guard engine.isAuthorized else { return }
        // SwiftUI 可能还没把 WebView 放进视图层级，这时候铺画面层会挂错位置。
        if webView.superview == nil {
            try? await Task.sleep(nanoseconds: 400_000_000)
        }
        await arm(in: webView)
    }

    @MainActor
    func arm(in webView: WKWebView) async {
        let engine = CameraEngine.shared
        wantsArmed = true
        host = webView

        if !engine.isRunning { startedByOverlay = true }
        await engine.start()
        var ready = await engine.waitUntilReady(timeout: 1.5)
        if !ready {
            // 可能刚被别的应用占着：整条链路重启一次再试。
            engine.stop()
            await engine.start()
            ready = await engine.waitUntilReady()
        }
        guard ready else { return }
        warmTask?.cancel()
        warmTask = nil

        // 画面层只建一次；重复 arm（比如从后台回来）沿用同一块。
        if surface == nil {
            let view = PreviewSurfaceView(session: engine.session)
            view.alpha = 0
            surface = view
            attach(view, to: webView, frame: webView.bounds)
        }
    }

    /// 把已经待命的画面显示出来。同步执行，不碰硬件、不等待，
    /// 所以从点击到看见画面只有一次消息往返的时间。
    @MainActor
    @discardableResult
    func reveal() -> Bool {
        guard let view = surface, let webView = host else { return false }
        warmTask?.cancel()
        warmTask = nil
        view.alpha = 1
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.isOpaque = false
        return true
    }

    /// 收起画面但保持相机待命，下次点开还是立刻出画面。
    @MainActor
    func conceal() {
        warmTask?.cancel()
        warmTask = nil
        surface?.alpha = 0
        restore(webView: host)
    }

    /// 真正停掉相机（App 进后台时用，避免后台空跑）。
    @MainActor
    func disarm() {
        wantsArmed = false
        warmTask?.cancel()
        warmTask = nil
        surface?.removeFromSuperview()
        surface = nil
        restore(webView: host)
        if startedByOverlay {
            startedByOverlay = false
            CameraEngine.shared.stop()
        }
    }

    @MainActor
    func start(in webView: WKWebView, frame: CGRect) async -> Bool {
        let engine = CameraEngine.shared

        // 待命中的相机直接显示，不走建层流程 —— 这是"点下去就是画面"的快路径。
        if let view = surface, engine.isRunning {
            host = webView
            attach(view, to: webView, frame: frame)
            view.alpha = 1
            webView.backgroundColor = .clear
            webView.scrollView.backgroundColor = .clear
            webView.isOpaque = false
            return true
        }

        let alreadyRunning = engine.isRunning
        await engine.start()
        // start() 里 isReady 是异步回主线程更新的，直接读会读到 false，
        // 那样网页就误以为"没有相机"退回去弹原生页了，所以这里要等它就绪。
        // 第一次别等太久：真起不来就赶紧重启重试，别让页面干等 3 秒。
        var ready = await engine.waitUntilReady(timeout: 1.5)
        if !ready {
            // 相机可能刚被别的应用占着（微信视频、系统相机没关干净）：
            // 整个链路重启一次再试，总比让网页跳去开系统相机好。
            engine.stop()
            await engine.start()
            ready = await engine.waitUntilReady()
        }
        guard ready else { return false }

        // 可能是点击时先暖过机，那次已经把相机跑起来了，这里不要把它改回 false，
        // 否则关闭拍摄页时会漏掉收尾、相机一直开着。
        if !alreadyRunning { startedByOverlay = true }
        warmTask?.cancel()
        warmTask = nil

        // 重复 start（比如页面重新挂载）时先清掉上一块画面，避免叠层。
        surface?.removeFromSuperview()

        host = webView
        let view = PreviewSurfaceView(session: engine.session)
        surface = view
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.isOpaque = false
        attach(view, to: webView, frame: frame)
        return true
    }

    private func attach(_ view: UIView, to webView: WKWebView, frame: CGRect) {
        if view.superview !== webView.superview {
            view.removeFromSuperview()
            if let superview = webView.superview {
                superview.insertSubview(view, belowSubview: webView)
            } else {
                webView.insertSubview(view, at: 0)
            }
        }
        view.frame = webView.superview.map { webView.convert(frame, to: $0) } ?? frame
    }

    private func restore(webView: WKWebView?) {
        guard let webView else { return }
        webView.backgroundColor = nil
        webView.scrollView.backgroundColor = nil
        webView.isOpaque = false
    }

    @MainActor
    func updateFrame(_ frame: CGRect) {
        guard let view = surface, let webView = host else { return }
        view.frame = webView.superview.map { webView.convert(frame, to: $0) } ?? frame
    }

    /// 离开拍摄页：只把画面收起来，**相机继续待命**。
    /// 这样下次点开还是立刻有画面，不用再等硬件加电。
    @MainActor
    func stop() {
        warmTask?.cancel()
        warmTask = nil
        surface?.alpha = 0
        restore(webView: host)
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
