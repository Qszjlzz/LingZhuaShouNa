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

    /// 等待照片回包的调用者。用数组而不是单个闭包，连拍时不会互相覆盖。
    private var pendingCaptures: [CheckedContinuation<UIImage?, Never>] = []
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

    /// 收尾所有等待照片的调用者。第一个拿到 image，其余按失败处理。
    @MainActor
    private func finishAllCaptures(with image: UIImage?) {
        let waiters = pendingCaptures
        pendingCaptures = []
        waiters.first?.resume(returning: image)
        waiters.dropFirst().forEach { $0.resume(returning: nil) }
    }

    var isAuthorized: Bool {
        AVCaptureDevice.authorizationStatus(for: .video) == .authorized
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
    func capturePhoto() async -> UIImage? {
        guard configured else { return nil }
        return await withCheckedContinuation { continuation in
            Task { @MainActor in self.pendingCaptures.append(continuation) }
            let settings = AVCapturePhotoSettings()
            settings.flashMode = torchEnabled ? .on : .off
            photoOutput.capturePhoto(with: settings, delegate: self)
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
            // 只把图交给第一个等待者，其余按 nil 收尾，避免连拍串味。
            self?.finishAllCaptures(with: image)
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
