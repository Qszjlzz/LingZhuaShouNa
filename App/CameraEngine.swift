import AVFoundation
import UIKit
import SwiftUI

/// 全 App 唯一的相机引擎。
///
/// 之前网页拍摄页依赖「把预览层垫在 WebView 底下 + WebView 透明」来偷画面，
/// 但 WKWebView 的内部内容层会自己绘制背景，真机上根本透不上来，
/// 于是用户看到的是网页自己的 UI，而不是相机。
/// 现在改成：相机画面由原生自己画在自己的页面里，不再穿透 WebView。
///
/// 同时这里承担两件事：
/// - 静态拍照（多张连拍），支持并发排队的 continuation；
/// - 实时抽帧（AR 扫描），按固定间隔把画面交给识别器。
final class CameraEngine: NSObject, ObservableObject {
    static let shared = CameraEngine()

    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "smartpaw.camera.session")

    /// 等待照片回包的调用者。用队列而不是单个闭包，连拍时不会互相覆盖。
    private var pendingCaptures: [PendingCapture] = []
    /// 拍照超时巡检。session 没跑起来时 AVCapturePhotoOutput 不会回调，
    /// 没有这层保护，等待者会永远挂着（网页侧表现为卡到 60 秒超时）。
    private var captureWatchdog: Task<Void, Never>?
    /// 单张照片最多等多久。正常拍摄 1 秒内就回来，8 秒足够宽松。
    private static let captureTimeout: TimeInterval = 8

    private struct PendingCapture {
        let id = UUID()
        let continuation: CheckedContinuation<UIImage?, Never>
        let deadline: Date
    }

    private var configured = false
    private var running = false

    /// 实时抽帧的回调（已节流，主线程调用）。
    var onLiveFrame: ((UIImage) -> Void)?
    /// 相邻两帧的最小间隔，避免把识别器压满。
    var liveFrameInterval: TimeInterval = 0.55
    private var lastFrameTime: TimeInterval = 0

    @Published private(set) var isRunning = false
    @Published private(set) var isReady = false
    @Published private(set) var permissionDenied = false
    @Published var torchEnabled = false

    private override init() { super.init() }

    // MARK: - Session lifecycle

    func start() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            break
        case .notDetermined:
            if await AVCaptureDevice.requestAccess(for: .video) == false {
                await setDenied()
                return
            }
        default:
            await setDenied()
            return
        }

        configureIfNeeded()
        await updateTorchIfPossible()
        startRunningIfNeeded()
    }

    func stop() {
        setTorch(on: false)
        onLiveFrame = nil
        guard running else { return }
        running = false
        isRunning = false
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
        }
        // 挂起中的拍照请求要给个结果，否则 continuation 泄漏。
        Task { @MainActor in self.finishAllCaptures(with: nil) }
    }

    /// 把刚拍到的这张交给排队最久的那个等待者（先进先出）。
    /// 剩下的继续等各自那张，不因为别人先回来就被判失败。
    @MainActor
    private func deliverCapture(_ image: UIImage?) {
        guard !pendingCaptures.isEmpty else { return }
        let first = pendingCaptures.removeFirst()
        first.continuation.resume(returning: image)
    }

    /// 收尾所有等待照片的调用者（相机停止 / 出错时调用）。
    @MainActor
    private func finishAllCaptures(with image: UIImage?) {
        let waiters = pendingCaptures
        pendingCaptures = []
        waiters.first?.continuation.resume(returning: image)
        waiters.dropFirst().forEach { $0.continuation.resume(returning: nil) }
    }

    var isAuthorized: Bool {
        AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }

    /// configure 之后 `isReady` 是回主线程异步刷新的，`start()` 一返回就立刻读
    /// 会读到 false。需要确认相机真的能用时，用这个方法等它就绪。
    @MainActor
    func waitUntilReady(timeout: TimeInterval = 3) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !isReady, Date() < deadline {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        return isReady
    }

    @MainActor
    private func setDenied() {
        permissionDenied = true
        isReady = false
    }

    private func configureIfNeeded() {
        guard !configured else { return }
        session.beginConfiguration()
        session.sessionPreset = .hd1280x720

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                ?? AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        guard session.canAddOutput(photoOutput) else {
            session.commitConfiguration()
            return
        }
        photoOutput.isHighResolutionCaptureEnabled = false
        session.addOutput(photoOutput)

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        if let connection = videoOutput.connection(with: .video) {
            connection.videoOrientation = .portrait
        }
        session.commitConfiguration()
        configured = true
        DispatchQueue.main.async { [weak self] in self?.isReady = true }
    }

    private func startRunningIfNeeded() {
        guard configured, !running else { return }
        running = true
        isRunning = true
        sessionQueue.async { [weak self] in
            self?.session.startRunning()
        }
    }

    // MARK: - Still capture

    /// 拍一张。可以连续调用，每次都会拿到自己的那张图。
    ///
    /// 请求按顺序排队：先请求的先拿到，各自独立回调，连拍不会串味也不会丢。
    /// 超过 `captureTimeout` 还没回包就按失败收尾，不让调用方无限等待。
    func capturePhoto() async -> UIImage? {
        guard configured else { return nil }
        return await withCheckedContinuation { continuation in
            Task { @MainActor in
                self.pendingCaptures.append(
                    PendingCapture(continuation: continuation,
                                   deadline: Date().addingTimeInterval(Self.captureTimeout))
                )
                self.startCaptureWatchdogIfNeeded()
            }
            let settings = AVCapturePhotoSettings()
            settings.flashMode = torchEnabled ? .on : .off
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    /// 有等待中的拍照请求时，周期性把超时的那几个按失败收尾。
    @MainActor
    private func startCaptureWatchdogIfNeeded() {
        guard captureWatchdog == nil else { return }
        captureWatchdog = Task { [weak self] in
            while true {
                try? await Task.sleep(nanoseconds: 250_000_000)
                if Task.isCancelled { break }
                guard let self, !self.pendingCaptures.isEmpty else { break }
                let now = Date()
                let expired = self.pendingCaptures.filter { $0.deadline <= now }
                guard !expired.isEmpty else { continue }
                let expiredIDs = Set(expired.map { $0.id })
                self.pendingCaptures.removeAll { expiredIDs.contains($0.id) }
                expired.forEach { $0.continuation.resume(returning: nil) }
            }
            self?.captureWatchdog = nil
        }
    }

    // MARK: - Torch

    func toggleTorch() {
        torchEnabled.toggle()
        updateTorchIfPossible()
    }

    private func updateTorchIfPossible() {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = torchEnabled ? .on : .off
            device.unlockForConfiguration()
        } catch {
            torchEnabled = false
        }
    }

    private func setTorch(on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
        } catch { /* 手电筒不可用不影响主流程 */ }
    }
}

extension CameraEngine: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let image = photo.fileDataRepresentation().flatMap(UIImage.init(data:))
        Task { @MainActor [weak self] in
            self?.deliverCapture(image)
        }
    }
}

extension CameraEngine: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = Date().timeIntervalSince1970
        guard now - lastFrameTime >= liveFrameInterval else { return }
        lastFrameTime = now

        guard let image = Self.image(from: sampleBuffer) else { return }
        DispatchQueue.main.async { [weak self] in
            self?.onLiveFrame?(image)
        }
    }

    /// 抽帧只给识别器用，缩到 512 宽足够，省掉大量拷贝开销。
    private static func image(from sampleBuffer: CMSampleBuffer) -> UIImage? {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let ciImage = CIImage(cvPixelBuffer: buffer)
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        let scale = 512.0 / Double(max(cgImage.width, 1))
        guard scale.isFinite, scale < 1 else { return UIImage(cgImage: cgImage) }
        let size = CGSize(width: Double(cgImage.width) * scale, height: Double(cgImage.height) * scale)
        UIGraphicsBeginImageContextWithOptions(size, false, 1)
        UIImage(cgImage: cgImage).draw(in: CGRect(origin: .zero, size: size))
        let scaled = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return scaled
    }
}
