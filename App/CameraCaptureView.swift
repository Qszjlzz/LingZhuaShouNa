import SwiftUI
import AVFoundation

/// App 内置取景框：直接在应用内拍照，不跳出系统相机。
/// 拍完先给一次确认（重拍 / 使用照片），再把图片交回原生流程做识别。
struct CameraCaptureView: View {
    var onCapture: (UIImage) -> Void
    var onCancel: () -> Void

    @StateObject private var camera = CameraController()
    @State private var captured: UIImage?
    @State private var unavailable = false
    @State private var isCapturing = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let shot = captured {
                Image(uiImage: shot)
                    .resizable()
                    .scaledToFit()
                    .ignoresSafeArea()
            } else {
                CameraPreviewView(session: camera.session)
                    .ignoresSafeArea()
            }

            if unavailable {
                VStack(spacing: 12) {
                    Image(systemName: "camera.slash")
                        .font(.system(size: 44))
                        .foregroundStyle(.white)
                    Text("相机不可用，请检查权限设置")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                    Button("返回") { onCancel() }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.white, in: Capsule())
                }
            } else {
                VStack {
                    HStack {
                        Button("取消") { onCancel() }
                            .font(.system(size: 17))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.black.opacity(0.35), in: Capsule())
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    Spacer()

                    if let shot = captured {
                        HStack(spacing: 28) {
                            CameraActionButton(title: "重拍", filled: false) { captured = nil }
                            CameraActionButton(title: "使用照片", filled: true) { onCapture(shot) }
                        }
                        .padding(.bottom, 44)
                    } else {
                        Button {
                            guard !isCapturing else { return }
                            isCapturing = true
                            camera.capture { image in
                                isCapturing = false
                                if let image { captured = image } else { unavailable = true }
                            }
                        } label: {
                            ZStack {
                                Circle().stroke(Color.white, lineWidth: 4).frame(width: 78, height: 78)
                                Circle().fill(Color.white).frame(width: 62, height: 62)
                            }
                        }
                        .disabled(isCapturing)
                        .accessibilityLabel("拍照")
                        .padding(.bottom, 20)

                        Text("对准要整理的空间，点击拍摄")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.bottom, 40)
                    }
                }
            }
        }
        .task {
            await camera.start()
            unavailable = !camera.isReady
        }
        .onDisappear { camera.stop() }
    }
}

private struct CameraActionButton: View {
    let title: String
    let filled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(filled ? .black : .white)
                .padding(.horizontal, 26)
                .padding(.vertical, 13)
                .background {
                    if filled {
                        Color.white
                    } else {
                        Color.white.opacity(0.22)
                    }
                }
                .clipShape(Capsule())
                .overlay {
                    if !filled {
                        Capsule().stroke(Color.white.opacity(0.6), lineWidth: 1)
                    }
                }
        }
    }
}

private struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        PreviewUIView(session: session)
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        uiView.updateFrame()
    }
}

private final class PreviewUIView: UIView {
    private let previewLayer = AVCaptureVideoPreviewLayer()

    init(session: AVCaptureSession) {
        super.init(frame: .zero)
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(previewLayer)
    }

    required init?(coder: NSCoder) { nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateFrame()
    }

    func updateFrame() {
        previewLayer.frame = bounds
    }
}

@MainActor
final class CameraController: NSObject, ObservableObject {
    private let engine = CameraEngine.shared
    var session: AVCaptureSession { engine.session }
    var isReady: Bool { engine.isReady && engine.isRunning }

    func start() async {
        await engine.start()
        _ = await engine.waitUntilReady()
    }

    func stop() { engine.stop() }

    func capture(completion: @escaping (UIImage?) -> Void) {
        Task { completion(await engine.capturePhoto()) }
    }
}
