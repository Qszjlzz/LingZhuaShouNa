import SwiftUI
import AVFoundation
import UIKit

/// 原生拍摄页。
///
/// 以前这一页是 WebView 里画的，相机画面垫在 WebView 底下靠「透明」偷出来，
/// 真机上根本透不上来，所以用户看到的其实是网页 UI 而不是相机；而且每张照片
/// 都要把全分辨率 JPEG 转 base64 塞回 JS，拍几张就把 WebView 撑爆退出。
///
/// 现在这一页完全由原生绘制：画面是自己的，照片留在原生侧，
/// 只在提交时把 240px 缩略图交给网页做展示，从根上不再有内存问题。
struct ScanStudioResult {
    /// 240px 缩略图的 data URL，只给网页做展示用。
    let thumbnails: [String]
    /// 原图留在原生侧做识别，不回传。
    let images: [UIImage]
}

struct ARDetection: Identifiable {
    let id: UUID
    let name: String
    var confidence: Double
    var hint: ARHint?
    var color: String
    /// 超过这个时间还刷不出来说明物品已离开画面，框要消失。
    var lastSeen: Date
}

@MainActor
final class ScanStudioModel: ObservableObject {
    enum Mode { case photo, ar }

    static let maxShots = 6
    private static let hints = ["广角", "左侧", "右侧", "俯视"]

    private let engine = CameraEngine.shared
    /// 用统一的识别路由：本地轮廓 + 云端多模态兜底，AR 实时扫描也不会出现"扫不出东西"。
    private let scanService = RecognitionRouter.shared

    @Published var mode: Mode
    @Published var shots: [UIImage] = []
    @Published var thumbs: [String] = []
    @Published var detections: [ARDetection] = []
    @Published var permissionError: String?
    @Published var notice: String?
    @Published var capturing = false
    @Published var shutterFlash = false
    @Published var recognizing = false
    @Published var torchOn = false

    init(mode: Mode) { self.mode = mode }

    var angleHint: String {
        Self.hints[min(shots.count, Self.hints.count - 1)]
    }

    var subtitle: String {
        switch mode {
        case .photo: return "\(shots.count) 张 · \(angleHint)"
        case .ar: return detections.isEmpty ? "正在对准……" : "已识别 \(detections.count) 件"
        }
    }

    func start() async {
        await engine.start()
        if engine.permissionDenied {
            permissionError = "没有相机权限。请到「设置 → 隐私与安全性 → 相机」里允许「灵爪收纳」后重试。"
            return
        }
        if mode == .ar { beginAR() }
    }

    func teardown() {
        // 先摘掉抽帧回调，再停 session，否则最后一帧会带着已经销毁的回调跑。
        engine.onLiveFrame = nil
        engine.stop()
    }

    func toggleTorch() {
        engine.toggleTorch()
        torchOn = engine.torchEnabled
    }

    // MARK: Still capture

    func snap() async {
        guard !capturing, shots.count < Self.maxShots else { return }
        capturing = true
        shutterFlash = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 180_000_000)
            shutterFlash = false
        }
        if let image = await engine.capturePhoto() {
            shots.append(image)
            if let thumb = Self.thumbnailDataURL(for: image) { thumbs.append(thumb) }
        } else {
            showNotice("这一张没拍到，对准后请重试")
        }
        capturing = false
    }

    // MARK: AR

    func switchToAR() {
        mode = .ar
        shots.removeAll()
        thumbs.removeAll()
        detections.removeAll()
        beginAR()
    }

    private func beginAR() {
        recognizing = false
        engine.liveFrameInterval = 0.55
        engine.onLiveFrame = { [weak self] image in
            guard let self else { return }
            Task { @MainActor in self.consumeFrame(image) }
        }
    }

    private func consumeFrame(_ image: UIImage) {
        guard !recognizing else { return }
        recognizing = true
        let service = scanService
        Task { [weak self] in
            let results = await service.scanLiveImage(image)
            await MainActor.run {
                guard let self else { return }
                self.recognizing = false
                if !results.isEmpty { self.merge(results) }
                self.dropStaleDetections()
            }
        }
    }

    /// 跨帧累物：同名同类保留置信度最高的一帧，位置跟随最新一帧。
    private func merge(_ incoming: [DetectedItem]) {
        var merged = detections
        let palette = ["#FA883A", "#7FA8C9", "#8B6F47", "#7BB89A", "#A8B8CC", "#E8B894", "#C98B8B", "#B4C7DC"]
        for item in incoming {
            if let index = merged.firstIndex(where: { $0.name == item.name }) {
                merged[index].confidence = max(merged[index].confidence, item.confidence)
                merged[index].hint = item.arHint ?? merged[index].hint
                merged[index].lastSeen = Date()
            } else {
                merged.append(ARDetection(
                    id: item.id,
                    name: item.name,
                    confidence: item.confidence,
                    hint: item.arHint,
                    color: palette[merged.count % palette.count],
                    lastSeen: Date()
                ))
            }
        }
        detections = Array(merged.prefix(8))
    }

    private func dropStaleDetections() {
        let cutoff = Date().addingTimeInterval(-2.5)
        let alive = detections.filter { $0.lastSeen > cutoff }
        if alive.count != detections.count { detections = alive }
    }

    // MARK: Commit

    func finish() -> ScanStudioResult? {
        guard !shots.isEmpty else { return nil }
        return ScanStudioResult(thumbnails: thumbs, images: shots)
    }

    /// AR 模式没有连拍，用最后识别帧作为整体环境照交给后续流程。
    func finishAR() async -> ScanStudioResult? {
        guard !detections.isEmpty else { return nil }
        var images: [UIImage] = []
        if let frame = await engine.capturePhoto() { images.append(frame) }
        return ScanStudioResult(thumbnails: images.compactMap { Self.thumbnailDataURL(for: $0) }, images: images)
    }

    private func showNotice(_ text: String) {
        notice = text
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            if notice == text { notice = nil }
        }
    }

    /// 只生成 240px 缩略图交给网页，避免大图 base64 撑爆 WebView。
    private static func thumbnailDataURL(for image: UIImage) -> String? {
        let ratio = image.size.height / max(image.size.width, 1)
        let target = CGSize(width: 240, height: 240 * ratio)
        UIGraphicsBeginImageContextWithOptions(target, false, 1)
        image.draw(in: CGRect(origin: .zero, size: target))
        let scaled = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        guard let scaled, let data = scaled.jpegData(compressionQuality: 0.6) else { return nil }
        return "data:image/jpeg;base64," + data.base64EncodedString()
    }
}

struct ScanStudioView: View {
    var initialMode: ScanStudioModel.Mode
    /// 网页按一次快门只收一张：拍完立刻回传，不留在原生页里继续拍。
    var singleShot: Bool
    var onCommit: (ScanStudioResult) -> Void
    var onCancel: () -> Void

    @StateObject private var model: ScanStudioModel

    init(initialMode: ScanStudioModel.Mode = .photo,
         singleShot: Bool = false,
         onCommit: @escaping (ScanStudioResult) -> Void,
         onCancel: @escaping () -> Void) {
        self.initialMode = initialMode
        self.singleShot = singleShot
        self.onCommit = onCommit
        self.onCancel = onCancel
        _model = StateObject(wrappedValue: ScanStudioModel(mode: initialMode))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            PreviewSurface(session: CameraEngine.shared.session)
                .ignoresSafeArea()

            DetectionLayer(detections: model.detections, visible: isAR)

            Vignette()

            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 0)
                if isPhoto { toolRow }
                bottomArea
            }
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .overlay { if shutterFlashVisible { Color.white.opacity(0.85).ignoresSafeArea().allowsHitTesting(false) } }
        .overlay { noticeOverlay }
        .task { await model.start() }
        .onDisappear { model.teardown() }
    }

    private var isAR: Bool { model.mode == .ar }
    private var isPhoto: Bool { model.mode == .photo }
    private var shutterFlashVisible: Bool { model.shutterFlash }

    // MARK: Building blocks

    private var topBar: some View {
        ZStack {
            HStack {
                CircleButton(systemImage: "xmark", size: 18, background: .white, foreground: .spCoffee) { onCancel() }
                Spacer()
            }
            statusCapsule
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var statusCapsule: some View {
        HStack(spacing: 6) {
            if isAR {
                Circle().fill(model.recognizing ? Color.spOrange : Color.spCoffee.opacity(0.4))
                    .frame(width: 7, height: 7)
            } else {
                Image(systemName: "sparkles").font(.system(size: 11)).foregroundStyle(Color.spOrange)
            }
            Text(model.subtitle)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.spCoffee)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.white.opacity(0.92), in: Capsule())
    }

    private var toolRow: some View {
        VStack(spacing: 0) {
            modeSwitcher
            CornerBrackets()
                .padding(.horizontal, 40)
                .frame(maxHeight: .infinity)
            CircleButton(systemImage: model.torchOn ? "bolt.fill" : "bolt",
                         size: 16,
                         background: model.torchOn ? .spOrange : .black.opacity(0.45),
                         foreground: .white) { model.toggleTorch() }
            .padding(.bottom, 4)
        }
    }

    private var modeSwitcher: some View {
        HStack(spacing: 2) {
            ModeChip(title: "多张连拍", icon: "camera", active: isPhoto) { model.mode = .photo }
            ModeChip(title: "AR 扫描", icon: "cube", active: isAR) { model.switchToAR() }
        }
        .padding(4)
        .background(.black.opacity(0.45), in: Capsule())
        .padding(.top, 6)
    }

    private var bottomArea: some View {
        VStack(spacing: 0) {
            if isAR { arPanel } else { photoDock }
        }
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.spLinen.opacity(0.95))
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private var photoDock: some View {
        VStack(spacing: 12) {
            if !model.thumbs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(model.thumbs.enumerated()), id: \.offset) { _, src in
                            ThumbView(dataURL: src)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }

            HStack {
                VStack(spacing: 1) {
                    Text("\(model.shots.count)")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.spCoffee)
                    Text("shots")
                        .font(.system(size: 8))
                        .foregroundStyle(Color.spCoffee.opacity(0.55))
                }
                .frame(width: 48, height: 48)
                .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Spacer()

                Button {
                    Task {
                        await model.snap()
                        let single = singleShot
                        await MainActor.run {
                            if single, let result = model.finish() { onCommit(result) }
                        }
                    }
                } label: {
                    ZStack {
                        Circle().stroke(Color.white, lineWidth: 4).frame(width: 72, height: 72)
                        Circle().fill(Color.spSoft).frame(width: 52, height: 52)
                    }
                }
                .disabled(model.capturing || model.shots.count >= ScanStudioModel.maxShots)
                .opacity(model.shots.count >= ScanStudioModel.maxShots ? 0.4 : 1)

                Spacer()

                Button {
                    if let result = model.finish() { onCommit(result) }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark").font(.system(size: 13, weight: .bold))
                        Text("完成").font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 48)
                    .background(model.shots.isEmpty ? Color.spSoft : Color.spOrange,
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .disabled(model.shots.isEmpty)
            }
            .padding(.horizontal, 20)

            Text(hintText)
                .font(.system(size: 10))
                .foregroundStyle(Color.spCoffee.opacity(0.5))
                .padding(.bottom, 8)
        }
        .padding(.top, 14)
    }

    private var arPanel: some View {
        VStack(spacing: 12) {
            if model.detections.isEmpty {
                Text("缓慢移动手机，让物品进入画面")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.spCoffee.opacity(0.6))
                    .frame(height: 44)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(model.detections) { item in
                            HStack(spacing: 6) {
                                Circle().fill(Color(hex: item.color)).frame(width: 8, height: 8)
                                Text(item.name).font(.system(size: 12, weight: .medium)).foregroundStyle(Color.spCoffee)
                                Text("\(Int(item.confidence * 100))%")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.spCoffee.opacity(0.45))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.white, in: Capsule())
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .frame(height: 44)
            }

            Button {
                Task { if let result = await model.finishAR() { onCommit(result) } }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "wand.and.stars").font(.system(size: 13, weight: .semibold))
                    Text(model.detections.isEmpty ? "识别中…" : "用这 \(model.detections.count) 件生成方案")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(model.detections.isEmpty ? Color.spSoft : Color.spOrange,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(model.detections.isEmpty)
            .padding(.horizontal, 20)

            Text("识别结果可直接生成整理方案")
                .font(.system(size: 10))
                .foregroundStyle(Color.spCoffee.opacity(0.5))
                .padding(.bottom, 8)
        }
        .padding(.top, 14)
    }

    private var hintText: String {
        if model.shots.isEmpty { return "拍摄不同角度以提高识别精度 · 下一角度：广角" }
        if model.shots.count >= ScanStudioModel.maxShots { return "已达到 \(ScanStudioModel.maxShots) 张上限，点击右下角完成" }
        return "拍摄不同角度以提高识别精度 · 下一角度：\(model.angleHint)"
    }

    @ViewBuilder
    private var noticeOverlay: some View {
        if let error = model.permissionError {
            permissionCard(error)
        } else if let notice = model.notice {
            Text(notice)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                .background(.black.opacity(0.65), in: Capsule())
                .padding(.top, 70)
                .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    private func permissionCard(_ text: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.slash").font(.system(size: 38)).foregroundStyle(.white)
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 26)
            Button("返回") { onCancel() }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.black)
                .padding(.horizontal, 26)
                .padding(.vertical, 12)
                .background(Color.white, in: Capsule())
        }
        .padding(30)
        .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(24)
    }
}

// MARK: - Canvas pieces

private struct DetectionLayer: View {
    let detections: [ARDetection]
    let visible: Bool

    var body: some View {
        GeometryReader { geo in
            if visible {
                ForEach(detections) { item in
                    ARDetectionBox(item: item, size: geo.size)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct ARDetectionBox: View {
    let item: ARDetection
    let size: CGSize

    var body: some View {
        let w = size.width * (item.hint?.width ?? 0)
        let h = size.height * (item.hint?.height ?? 0)
        let cx = size.width * (item.hint?.x ?? 0.5)
        let cy = size.height * (item.hint?.y ?? 0.5)

        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(hex: item.color).opacity(0.14))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color(hex: item.color), lineWidth: 2)
                }
            Text("\(item.name) \(Int(item.confidence * 100))%")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color(hex: item.color), in: Capsule())
                .offset(y: -22)
        }
        .frame(width: max(w, 1), height: max(h, 1))
        .position(x: cx, y: cy)
        .animation(.easeOut(duration: 0.22), value: item.confidence)
    }
}

private struct Vignette: View {
    var body: some View {
        RadialGradient(colors: [.clear, .black.opacity(0.35)], center: .center, startRadius: 0, endRadius: 520)
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }
}

private struct PreviewSurface: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> SurfaceView { SurfaceView(session: session) }
    func updateUIView(_ uiView: SurfaceView, context: Context) { uiView.updateFrame() }

    final class SurfaceView: UIView {
        private let preview = AVCaptureVideoPreviewLayer()

        init(session: AVCaptureSession) {
            preview.session = session
            preview.videoGravity = .resizeAspectFill
            super.init(frame: .zero)
            backgroundColor = .black
            layer.addSublayer(preview)
        }

        required init?(coder: NSCoder) { nil }

        override func layoutSubviews() {
            super.layoutSubviews()
            updateFrame()
        }

        func updateFrame() {
            preview.frame = bounds
            if let connection = preview.connection, connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
        }
    }
}

private struct CircleButton: View {
    let systemImage: String
    let size: CGFloat
    var background: Color
    var foreground: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(foreground)
                .frame(width: 40, height: 40)
                .background(background, in: Circle())
        }
    }
}

private struct ModeChip: View {
    let title: String
    let icon: String
    let active: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11))
                Text(title).font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(active ? Color.spCoffee : .white)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(active ? Color.white : Color.clear, in: Capsule())
        }
    }
}

private struct CornerBrackets: View {
    var body: some View {
        ZStack {
            bracket(.topLeading)
            bracket(.topTrailing)
            bracket(.bottomLeading)
            bracket(.bottomTrailing)
        }
    }

    private func bracket(_ spot: Alignment) -> some View {
        let top = spot == .topLeading || spot == .topTrailing
        let left = spot == .topLeading || spot == .bottomLeading
        return ZStack(alignment: spot) {
            Color.clear
            ZStack(alignment: .topLeading) {
                Rectangle().fill(Color.white.opacity(0.75)).frame(width: 26, height: 2)
                Rectangle().fill(Color.white.opacity(0.75)).frame(width: 2, height: 26)
            }
            .rotationEffect(.degrees(top ? 0 : 180), anchor: .center)
            .rotation3DEffect(.degrees(left ? 0 : 180), axis: (x: 0, y: 1, z: 0))
        }
    }
}

private struct ThumbView: View {
    let dataURL: String

    var body: some View {
        let raw = dataURL.replacingOccurrences(of: "data:image/jpeg;base64,", with: "")
        Group {
            if let data = Data(base64Encoded: raw), let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Color.spSoft
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.spOrange, lineWidth: 2)
        }
    }
}

// MARK: - Colors

extension Color {
    static let spCoffee = Self(hexValue: 0x7B5C48)
    static let spOrange = Self(hexValue: 0xFA883A)
    static let spLinen = Self(hexValue: 0xF6F1EB)
    static let spSoft = Self(hexValue: 0xEFE6DC)

    init(hexValue value: UInt32) {
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    init(hex string: String) {
        var cleaned = string.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if cleaned.count == 6 { cleaned = "FF" + cleaned }
        guard cleaned.count == 8, let value = UInt32(cleaned, radix: 16) else {
            self = Self(hexValue: 0xFA883A)
            return
        }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
