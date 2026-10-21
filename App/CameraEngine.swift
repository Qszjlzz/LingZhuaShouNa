import AVFoundation
import UIKit
import SwiftUI

/// One camera session shared by the web preview and native capture screens.
final class CameraEngine: NSObject, ObservableObject {
    static let shared = CameraEngine()

    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "smartpaw.camera.session")
    // Configuration and capture commands run on sessionQueue; UI intent stays on the main actor.
    private var configured = false
    private var wantsRunning = false
    private var lifecycleGeneration = 0
    private var pendingCaptures: [Int64: PendingCapture] = [:]
    private var captureWatchdog: Task<Void, Never>?
    private static let captureTimeout: TimeInterval = 8
    private static let imageContext = CIContext(options: [.useSoftwareRenderer: false])

    private struct PendingCapture {
        let continuation: CheckedContinuation<UIImage?, Never>
        let deadline: Date
    }

    var onLiveFrame: ((UIImage) -> Void)?
    private let frameIntervalLock = NSLock()
    private var frameInterval: TimeInterval = 0.55
    var liveFrameInterval: TimeInterval {
        get { frameIntervalLock.lock(); defer { frameIntervalLock.unlock() }; return frameInterval }
        set { frameIntervalLock.lock(); defer { frameIntervalLock.unlock() }; frameInterval = max(0.1, newValue) }
    }
    private var lastFrameTime: TimeInterval = 0

    @Published private(set) var isRunning = false
    @Published private(set) var isReady = false
    @Published private(set) var permissionDenied = false
    @Published var torchEnabled = false

    private override init() {
        super.init()
        let center = NotificationCenter.default
        for name in [Notification.Name.AVCaptureSessionRuntimeError, .AVCaptureSessionWasInterrupted, .AVCaptureSessionInterruptionEnded] {
            center.addObserver(forName: name, object: session, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.isRunning = false
                    self.isReady = false
                    self.finishAllCaptures()
                    if name != .AVCaptureSessionWasInterrupted,
                       self.wantsRunning, UIApplication.shared.applicationState != .background {
                        await self.start()
                    }
                }
            }
        }
        center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.suspendForBackground() }
        }
        center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.wantsRunning else { return }
                await self.start()
            }
        }
    }

    @MainActor
    func start() async {
        wantsRunning = true
        lifecycleGeneration += 1
        let generation = lifecycleGeneration
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: break
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .video) else { setDenied(); return }
        default: setDenied(); return
        }
        guard wantsRunning, generation == lifecycleGeneration,
              UIApplication.shared.applicationState != .background else { return }
        permissionDenied = false
        await withCheckedContinuation { continuation in
            sessionQueue.async { [weak self] in
                guard let self else { continuation.resume(); return }
                self.configureIfNeeded()
                if self.configured, !self.session.isRunning { self.session.startRunning() }
                let running = self.session.isRunning
                DispatchQueue.main.async {
                    if self.wantsRunning, generation == self.lifecycleGeneration {
                        self.isRunning = running
                        self.isReady = running
                        if running { self.updateTorchIfPossible() }
                    }
                    continuation.resume()
                }
            }
        }
    }

    @MainActor
    func stop() {
        wantsRunning = false
        lifecycleGeneration += 1
        stopSession(clearLiveHandler: true)
    }

    @MainActor
    private func suspendForBackground() {
        // Keep the current screen's intent so an open native camera can resume on return.
        lifecycleGeneration += 1
        stopSession(clearLiveHandler: false)
    }

    @MainActor
    private func stopSession(clearLiveHandler: Bool) {
        torchEnabled = false
        updateTorchIfPossible()
        if clearLiveHandler { onLiveFrame = nil }
        isRunning = false
        isReady = false
        finishAllCaptures()
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    @MainActor
    private func setDenied() {
        permissionDenied = true
        wantsRunning = false
        stopSession(clearLiveHandler: true)
    }

    var isAuthorized: Bool { AVCaptureDevice.authorizationStatus(for: .video) == .authorized }

    @MainActor
    func prepareIfAuthorized() async {
        guard isAuthorized else { return }
        await withCheckedContinuation { continuation in
            sessionQueue.async { [weak self] in
                self?.configureIfNeeded()
                continuation.resume()
            }
        }
    }

    @MainActor
    func waitUntilReady(timeout: TimeInterval = 3) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !(isReady && isRunning), !permissionDenied, Date() < deadline, !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        return isReady && isRunning && !Task.isCancelled
    }

    private func configureIfNeeded() {
        guard !configured else { return }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .hd1280x720
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) ?? AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input),
              session.canAddOutput(photoOutput) else { return }
        session.addInput(input)
        session.addOutput(photoOutput)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }
        for connection in [videoOutput.connection(with: .video), photoOutput.connection(with: .video)].compactMap({ $0 }) {
            if #available(iOS 17.0, *), connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            } else if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
        }
        configured = true
    }

    @MainActor
    func capturePhoto() async -> UIImage? {
        guard isReady, isRunning, wantsRunning else { return nil }
        let settings = AVCapturePhotoSettings()
        settings.flashMode = torchEnabled && photoOutput.supportedFlashModes.contains(.on) ? .on : .off
        let id = settings.uniqueID
        return await withCheckedContinuation { continuation in
            // Register before issuing the request. AVFoundation may deliver photos out of order.
            pendingCaptures[id] = PendingCapture(continuation: continuation, deadline: Date().addingTimeInterval(Self.captureTimeout))
            startCaptureWatchdogIfNeeded()
            sessionQueue.async { [weak self] in
                guard let self else { return }
                guard self.session.isRunning else {
                    Task { @MainActor in self.deliverCapture(nil, id: id) }
                    return
                }
                self.photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    @MainActor
    private func deliverCapture(_ image: UIImage?, id: Int64) {
        // A timed-out or cancelled request's late photo must never satisfy a newer request.
        pendingCaptures.removeValue(forKey: id)?.continuation.resume(returning: image)
    }

    @MainActor
    private func finishAllCaptures() {
        let pending = pendingCaptures.values
        pendingCaptures = [:]
        pending.forEach { $0.continuation.resume(returning: nil) }
    }

    @MainActor
    private func startCaptureWatchdogIfNeeded() {
        guard captureWatchdog == nil else { return }
        captureWatchdog = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 250_000_000)
                guard !Task.isCancelled, let self, !self.pendingCaptures.isEmpty else { break }
                let now = Date()
                let expired = self.pendingCaptures.filter { $0.value.deadline <= now }.map(\.key)
                for id in expired { self.deliverCapture(nil, id: id) }
            }
            self?.captureWatchdog = nil
        }
    }

    @MainActor
    func toggleTorch() {
        guard isRunning else { return }
        torchEnabled.toggle()
        updateTorchIfPossible()
    }

    @MainActor
    private func updateTorchIfPossible() {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { torchEnabled = false; return }
        do {
            try device.lockForConfiguration()
            device.torchMode = torchEnabled ? .on : .off
            device.unlockForConfiguration()
        } catch { torchEnabled = false }
    }
}

extension CameraEngine: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let image = error == nil ? photo.fileDataRepresentation().flatMap(UIImage.init(data:)) : nil
        let id = photo.resolvedSettings.uniqueID
        Task { @MainActor [weak self] in self?.deliverCapture(image, id: id) }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        guard error != nil else { return }
        let id = resolvedSettings.uniqueID
        Task { @MainActor [weak self] in self?.deliverCapture(nil, id: id) }
    }
}

extension CameraEngine: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = Date().timeIntervalSince1970
        guard now - lastFrameTime >= liveFrameInterval else { return }
        lastFrameTime = now
        guard let image = Self.image(from: sampleBuffer) else { return }
        Task { @MainActor [weak self] in
            guard let self, self.isRunning else { return }
            self.onLiveFrame?(image)
        }
    }

    private static func image(from sampleBuffer: CMSampleBuffer) -> UIImage? {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let ciImage = CIImage(cvPixelBuffer: buffer)
        guard let cgImage = imageContext.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        let scale = 512.0 / Double(max(cgImage.width, 1))
        guard scale.isFinite, scale < 1 else { return UIImage(cgImage: cgImage) }
        let size = CGSize(width: Double(cgImage.width) * scale, height: Double(cgImage.height) * scale)
        return UIGraphicsImageRenderer(size: size, format: {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            return format
        }()).image { _ in UIImage(cgImage: cgImage).draw(in: CGRect(origin: .zero, size: size)) }
    }
}
