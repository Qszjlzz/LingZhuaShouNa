import AVFoundation
import PhotosUI
import RoomPlan
import SwiftUI

struct CaptureView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @StateObject private var cameraModel = CaptureCameraModel()
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isShowingRoomScanner = false
    @State private var selectedRegionItemID: UUID?
    @State private var selectedScanMode: CaptureScanMode = .multiCamera
    @State private var multiCameraImages: [UIImage] = []
    @State private var isARScanRecording = false
    @State private var isShowingScanReview = false
    @State private var isShowingMultiCameraPreview = false
    @State private var didScheduleDebugCountdown = false
    @State private var didSeedDebugCaptureState = false

    var body: some View {
        CaptureCameraPanel(
            selectedItemID: $selectedRegionItemID,
            selectedPhotoItem: $selectedPhotoItem,
            isShowingRoomScanner: $isShowingRoomScanner,
            selectedMode: $selectedScanMode,
            multiCameraImages: $multiCameraImages,
            isARScanRecording: $isARScanRecording,
            cameraModel: cameraModel,
            onFinished: {
                cameraModel.stop()
                isShowingScanReview = true
            },
            onMultiCameraFinished: {
                cameraModel.stop()
                isShowingMultiCameraPreview = true
            }
        )
        .ignoresSafeArea()
        .statusBar(hidden: true)
        .toolbar(.hidden, for: .tabBar)
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item else { return }
            Task { await loadPhoto(item) }
        }
        .sheet(isPresented: $isShowingRoomScanner) {
            RoomScannerSheet()
        }
        .fullScreenCover(isPresented: $isShowingScanReview) {
            FigmaScanConfirmationView(selectedItemID: $selectedRegionItemID)
                .environmentObject(viewModel)
        }
        .sheet(isPresented: $isShowingMultiCameraPreview) {
            MultiCameraPreviewView(images: multiCameraImages) {
                isShowingMultiCameraPreview = false
                isShowingScanReview = true
            }
            .environmentObject(viewModel)
        }
        .task {
            guard viewModel.selectedTab == .capture else { return }
            #if DEBUG
            if CommandLine.arguments.contains("-SmartPawScreenshotReview") {
                await viewModel.scanBundledSample(assetName: AppSampleAssets.messyDesk)
                isShowingScanReview = true
                return
            }
            #endif
            guard !shouldSkipCameraStartupForDebugSample else { return }
            cameraModel.start()
            showDebugCountdownIfRequested()
        }
        .onChange(of: viewModel.selectedTab) { _, tab in
            if tab == .capture {
                if !isShowingScanReview {
                    guard !shouldSkipCameraStartupForDebugSample else { return }
                    cameraModel.start()
                }
                showDebugCountdownIfRequested()
            } else {
                cameraModel.stop()
            }
        }
        .onChange(of: isShowingScanReview) { _, isShowing in
            if !isShowing, viewModel.selectedTab == .capture {
                cameraModel.start()
            }
        }
        .onChange(of: selectedScanMode) { _, mode in
            if mode != .arScan {
                isARScanRecording = false
            }
            cameraModel.setLiveRecognitionEnabled(mode == .arScan)
        }
        .onAppear {
            cameraModel.setLiveRecognitionEnabled(selectedScanMode == .arScan)
            seedDebugCaptureStateIfRequested()
        }
        .onDisappear {
            cameraModel.stop()
        }
    }

    private var shouldSkipCameraStartupForDebugSample: Bool {
        #if DEBUG
        return CommandLine.arguments.contains("-SmartPawAutoVisionScan")
            || CommandLine.arguments.contains("-SmartPawAutoCaptureSample")
        #else
        return false
        #endif
    }

    private func loadPhoto(_ item: PhotosPickerItem) async {
        if selectedScanMode == .multiCamera {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage.downsampled(data: data)
            else {
                viewModel.showMessage("无法读取这张照片，请换一张图片重试。")
                return
            }
            appendMultiCameraImage(image)
            return
        }
        cameraModel.beginStillCapture()
        cameraModel.beginScanFeedback(duration: 4)
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage.downsampled(data: data)
            else {
                cameraModel.endScanFeedback()
                cameraModel.endStillCapture()
                viewModel.showMessage("无法读取这张照片，请换一张图片重试。")
                return
            }
            await viewModel.scanImage(image)
            cameraModel.endScanFeedback()
            cameraModel.endStillCapture()
        } catch {
            cameraModel.endScanFeedback()
            cameraModel.endStillCapture()
            viewModel.showMessage("导入照片失败：\(error.localizedDescription)")
        }
    }

    private func appendMultiCameraImage(_ image: UIImage) {
        guard multiCameraImages.count < 2 else {
            viewModel.showMessage("两张多镜头素材已经准备好了，可以进入预览。")
            return
        }
        multiCameraImages.append(image)
        viewModel.showMessage(multiCameraImages.count == 2 ? "两张素材已准备就绪。" : "已拍好第 1 张，请换一个角度再拍 1 张。")
    }

    private func showDebugCountdownIfRequested() {
        #if DEBUG
        guard CommandLine.arguments.contains("-SmartPawAutoCaptureCountdown"),
              !didScheduleDebugCountdown
        else { return }
        didScheduleDebugCountdown = true
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                cameraModel.beginScanFeedback(duration: 12)
            }
        }
        #endif
    }

    private func seedDebugCaptureStateIfRequested() {
        #if DEBUG
        guard !didSeedDebugCaptureState else { return }
        didSeedDebugCaptureState = true

        if CommandLine.arguments.contains("-SmartPawCaptureOneClip") {
            selectedScanMode = .multiCamera
            if let image = UIImage(named: AppSampleAssets.messyDesk) {
                multiCameraImages = [image]
            }
        }

        if CommandLine.arguments.contains("-SmartPawCaptureRecording") {
            selectedScanMode = .arScan
            isARScanRecording = true
            cameraModel.beginScanFeedback(duration: 20)
        }

        if CommandLine.arguments.contains("-SmartPawCaptureARIdle") {
            selectedScanMode = .arScan
        }
        #endif
    }
}

private enum CaptureScanMode: String, CaseIterable, Identifiable {
    case multiCamera = "多镜头"
    case arScan = "AR 扫描"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .multiCamera: "camera.viewfinder"
        case .arScan: "cube.transparent"
        }
    }
}

private struct CaptureCameraPanel: View {
    @Binding var selectedItemID: UUID?
    @Binding var selectedPhotoItem: PhotosPickerItem?
    @Binding var isShowingRoomScanner: Bool
    @Binding var selectedMode: CaptureScanMode
    @Binding var multiCameraImages: [UIImage]
    @Binding var isARScanRecording: Bool
    @ObservedObject var cameraModel: CaptureCameraModel
    let onFinished: () -> Void
    let onMultiCameraFinished: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Color.black
                    .ignoresSafeArea()

                ScanPreview(
                    selectedItemID: $selectedItemID,
                    selectedMode: selectedMode,
                    cameraModel: cameraModel
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()

                VStack(spacing: 12) {
                    CaptureCameraTopBar(
                        selectedMode: $selectedMode,
                        multiCameraCount: multiCameraImages.count,
                        isARScanRecording: isARScanRecording,
                        cameraModel: cameraModel
                    )
                    Spacer(minLength: 0)
                    CaptureActions(
                        selectedPhotoItem: $selectedPhotoItem,
                        isShowingRoomScanner: $isShowingRoomScanner,
                        selectedMode: selectedMode,
                        multiCameraImages: $multiCameraImages,
                        isARScanRecording: $isARScanRecording,
                        cameraModel: cameraModel,
                        onFinished: onFinished,
                        onMultiCameraFinished: onMultiCameraFinished
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, proxy.safeAreaInsets.top + 22)
                .padding(.bottom, proxy.safeAreaInsets.bottom + 8)
            }
        }
    }
}

private struct CaptureCameraTopBar: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Binding var selectedMode: CaptureScanMode
    let multiCameraCount: Int
    let isARScanRecording: Bool
    @ObservedObject var cameraModel: CaptureCameraModel

    var body: some View {
        VStack(spacing: 11) {
            HStack {
                Button {
                    viewModel.selectedTab = .space
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(SmartPawStyle.brown)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(CaptureCircleButtonStyle())
                .accessibilityLabel("关闭拍摄")

                Spacer()

                Label(statusText, systemImage: isRecording ? "record.circle.fill" : "sparkles")
                    .font(FigmaFont.medium(9))
                    .foregroundStyle(isRecording ? .white : SmartPawStyle.brown)
                    .padding(.horizontal, 12)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .frame(height: 30)
                    .background(isRecording ? SmartPawStyle.scanRed : .white.opacity(0.92), in: Capsule())
            }

            HStack(spacing: 3) {
                ForEach(CaptureScanMode.allCases) { mode in
                    Button {
                        selectedMode = mode
                    } label: {
                        Label(mode.rawValue, systemImage: mode.iconName)
                            .labelStyle(.titleAndIcon)
                            .font(FigmaFont.medium(9))
                            .frame(width: 84, height: 34)
                    }
                    .buttonStyle(CaptureModeButtonStyle(isSelected: selectedMode == mode))
                }
            }
            .padding(3)
            .background(Color.black.opacity(0.28), in: Capsule())
        }
    }

    private var statusText: String {
        if selectedMode == .multiCamera { return "\(multiCameraCount) shots · 广角" }
        if isRecording { return "REC 0:03" }
        // The HUD describes the active capture mode rather than device capability.
        // This keeps its visual state stable on hardware and in Simulator.
        return "AR扫描状态"
    }

    private var isRecording: Bool {
        selectedMode == .arScan && (isARScanRecording || viewModel.isScanning || cameraModel.isRecognizing)
    }
}

private struct ScanPreview: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Binding var selectedItemID: UUID?
    let selectedMode: CaptureScanMode
    @ObservedObject var cameraModel: CaptureCameraModel

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if cameraModel.canShowLiveCamera {
                    EmbeddedCameraView(cameraModel: cameraModel)
                        .ignoresSafeArea()

                    ForEach(liveMaskItems) { item in
                        if item.arHint != nil, let mask = item.arMask {
                            ScanDetectionMask(item: item, mask: mask, imageRect: CGRect(origin: .zero, size: proxy.size))
                                .opacity(selectedItemID == nil || selectedItemID == item.id ? 1 : 0.42)
                        }
                    }

                    ForEach(boxOnlyItems) { item in
                        if let hint = item.arHint {
                            ScanDetectionBox(item: item, hint: hint, imageRect: CGRect(origin: .zero, size: proxy.size))
                        }
                    }

                    ForEach(visibleLabelItems) { item in
                        ScanItemNameTag(
                            item: item,
                            mask: item.arMask,
                            imageRect: CGRect(origin: .zero, size: proxy.size),
                            visibleRect: CGRect(origin: .zero, size: proxy.size),
                            isSelected: selectedItemID == nil || selectedItemID == item.id
                        ) {
                            selectedItemID = item.id
                        }
                    }
                } else if let image = viewModel.capturedImage ?? simulatorPreviewImage {
                    let imageRect = aspectFillRect(imageSize: image.size, in: proxy.size)
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: imageRect.width, height: imageRect.height)
                        .position(x: imageRect.midX, y: imageRect.midY)

                    ForEach(previewItems) { item in
                        if item.arHint != nil, let mask = item.arMask {
                            ScanDetectionMask(item: item, mask: mask, imageRect: imageRect)
                                .opacity(selectedItemID == nil || selectedItemID == item.id ? 1 : 0.42)
                        }
                    }

                    ForEach(boxOnlyItems) { item in
                        if let hint = item.arHint {
                            ScanDetectionBox(item: item, hint: hint, imageRect: imageRect)
                        }
                    }

                    ForEach(visibleLabelItems) { item in
                        ScanItemNameTag(
                            item: item,
                            mask: item.arMask,
                            imageRect: imageRect,
                            visibleRect: CGRect(origin: .zero, size: proxy.size),
                            isSelected: selectedItemID == nil || selectedItemID == item.id
                        ) {
                            selectedItemID = item.id
                        }
                    }
                } else {
                    CameraViewfinderPlaceholder()
                }

                if selectedMode == .arScan {
                    ScanCornerOverlay()
                        .padding(.horizontal, 28)
                        .padding(.top, 132)
                        .padding(.bottom, 150)
                        .allowsHitTesting(false)
                }

                VStack {
                    Spacer()
                    EmptyView()
                }
                .padding(.horizontal, 54)
                .padding(.top, 168)
                .padding(.bottom, 138)

                if shouldShowScanCountdown {
                    ScanCountdownHUD(deadline: cameraModel.scanFeedbackDeadline ?? debugCountdownDeadline)
                        .offset(y: -160)
                        .transition(.scale(scale: 0.92).combined(with: .opacity))
                }
            }
        }
        .clipped()
        .animation(.easeOut(duration: 0.18), value: shouldShowScanCountdown)
        .accessibilityLabel("相机扫描预览")
    }

    private var shouldShowScanCountdown: Bool {
        if cameraModel.isStillCaptureInProgress || viewModel.isScanning { return true }
        #if DEBUG
        return CommandLine.arguments.contains("-SmartPawAutoCaptureCountdown")
        #else
        return false
        #endif
    }

    private var debugCountdownDeadline: Date? {
        #if DEBUG
        if CommandLine.arguments.contains("-SmartPawAutoCaptureCountdown") {
            return Date().addingTimeInterval(8)
        }
        #endif
        return nil
    }

    private var selectedItem: DetectedItem? {
        guard let selectedItemID else { return nil }
        return displayItems.first { $0.id == selectedItemID }
    }

    private var displayItems: [DetectedItem] {
        guard selectedMode == .arScan else { return [] }
        guard !cameraModel.isStillCaptureInProgress, !viewModel.isScanning else { return [] }
        return cameraModel.items
    }

    private var liveMaskItems: [DetectedItem] {
        guard selectedMode == .arScan,
              !cameraModel.isStillCaptureInProgress,
              !viewModel.isScanning
        else { return [] }
        return cameraModel.items.filter { $0.arMask?.hasRaster == true }
    }

    private var previewItems: [DetectedItem] {
        guard !cameraModel.isStillCaptureInProgress, !viewModel.isScanning else { return [] }
        return (liveMaskItems.isEmpty ? viewModel.scannedItems : liveMaskItems)
            .filter { $0.arMask?.hasRaster == true }
    }

    private var boxOnlyItems: [DetectedItem] {
        guard !cameraModel.isStillCaptureInProgress, !viewModel.isScanning else { return [] }
        if selectedMode == .arScan {
            return cameraModel.items.filter { $0.arHint != nil && $0.arMask?.hasRaster != true }
        }
        let candidates = cameraModel.items.isEmpty ? viewModel.scannedItems : cameraModel.items
        return candidates.filter { $0.arHint != nil && $0.arMask == nil }
    }

    private var visibleLabelItems: [DetectedItem] {
        guard !cameraModel.isStillCaptureInProgress, !viewModel.isScanning else { return [] }
        if selectedMode == .arScan {
            return cameraModel.items.sorted { $0.confidence > $1.confidence }
        }
        let candidates = liveMaskItems.isEmpty ? previewItems : liveMaskItems
        return candidates
            .sorted { $0.confidence > $1.confidence }
            .map { $0 }
    }

    private var simulatorPreviewImage: UIImage? {
        #if targetEnvironment(simulator)
        return UIImage(named: AppSampleAssets.messyDesk)
        #else
        return nil
        #endif
    }

    private func aspectFillRect(imageSize: CGSize, in containerSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CGRect(origin: .zero, size: containerSize)
        }
        let scale = max(containerSize.width / imageSize.width, containerSize.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: (containerSize.width - size.width) / 2,
            y: (containerSize.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }
}

private struct ScanCornerOverlay: View {
    var body: some View {
        ViewfinderCorner()
            .stroke(.white.opacity(0.78), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
    }
}

private struct FigmaScanConfirmationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: AppViewModel
    @Binding var selectedItemID: UUID?
    @State private var stage: ReviewStage = .preview
    @State private var sheet: ReviewSheet?
    @State private var manualName = ""
    @State private var manualCategory: ItemCategory = .books

    private enum ReviewStage { case preview, confirmed }
    private enum ReviewSheet: Identifiable { case organize, library, manual; var id: Int { hashValue } }

    var body: some View {
        NavigationStack {
            ZStack {
                SmartPawStyle.canvas.ignoresSafeArea()
                VStack(spacing: 0) {
                    if stage == .preview {
                        reviewHeader
                            .padding(.horizontal, 18)
                            .padding(.top, 14)
                    }

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            previewPhoto
                                .padding(.top, stage == .preview ? 18 : 20)
                            if stage == .preview {
                                previewControls
                            } else {
                                confirmedControls
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.bottom, 24)
                    }
                }
            }
            .sheet(item: $sheet) { activeSheet in
                switch activeSheet {
                case .organize: organizeSheet
                case .library: librarySheet
                case .manual: manualSheet
                }
            }
            .statusBar(hidden: true)
            #if DEBUG
            .onAppear {
                if CommandLine.arguments.contains("-SmartPawScreenshotConfirmedReview") {
                    stage = .confirmed
                }
            }
            #endif
        }
    }

    private var reviewHeader: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 34, height: 34)
                    .background(.white, in: Circle())
            }
            Spacer()
            VStack(spacing: 2) {
                Text(stage == .confirmed ? "识别确认" : "预览结果")
                    .font(FigmaFont.semibold(15))
                Text(stage == .confirmed ? "\(viewModel.scannedItems.count)个项目 · 2个盲点" : "\(max(2, viewModel.scannedItems.count)) assets ready")
                    .font(FigmaFont.regular(9))
                    .foregroundStyle(SmartPawStyle.brown.opacity(0.55))
            }
            Spacer()
            Button { sheet = .manual } label: {
                Label("添加", systemImage: "camera")
                    .font(FigmaFont.medium(10))
                    .padding(.horizontal, 11)
                    .frame(height: 30)
                    .background(.white, in: Capsule())
            }
        }
        .foregroundStyle(SmartPawStyle.brown)
    }

    private var previewPhoto: some View {
        GeometryReader { proxy in
            let sourceImage = viewModel.capturedImage ?? UIImage(named: AppSampleAssets.messyDesk)
            let imageRect = aspectFillRect(
                imageSize: sourceImage?.size ?? CGSize(width: 4, height: 3),
                in: proxy.size
            )
            ZStack(alignment: .topLeading) {
                if let image = sourceImage {
                    Image(uiImage: image)
                        .resizable()
                        .frame(width: imageRect.width, height: imageRect.height)
                        .position(x: imageRect.midX, y: imageRect.midY)
                } else {
                    StorageImageView(url: nil, assetName: AppSampleAssets.messyDesk, fallbackProgress: 0)
                }
                if stage == .confirmed {
                    ForEach(Array(blindSpotItems.enumerated()), id: \.element.id) { index, item in
                        ReviewBlindSpotOverlay(
                            item: item,
                            index: index,
                            imageRect: imageRect,
                            visibleRect: CGRect(origin: .zero, size: proxy.size)
                        ) {
                            selectedItemID = item.id
                        }
                    }
                }
                if stage == .confirmed {
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(SmartPawStyle.brown)
                                .frame(width: 32, height: 32)
                                .background(.white.opacity(0.94), in: Circle())
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Label("\(viewModel.scannedItems.count)个项目 · \(blindSpotItems.count)个盲点", systemImage: "sparkles")
                            .font(FigmaFont.medium(9))
                            .foregroundStyle(SmartPawStyle.brown.opacity(0.78))
                            .padding(.horizontal, 11)
                            .frame(height: 30)
                            .background(.white.opacity(0.94), in: Capsule())
                    }
                    .padding(12)
                }
            }
            .clipped().clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .frame(height: stage == .confirmed ? 306 : 342)
    }

    private var blindSpotItems: [DetectedItem] {
        Array(viewModel.scannedItems
            .filter { $0.arHint != nil || $0.arMask?.isRenderable == true }
            .sorted { $0.confidence < $1.confidence }
            .prefix(2))
    }

    private func aspectFillRect(imageSize: CGSize, in containerSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CGRect(origin: .zero, size: containerSize)
        }
        let scale = max(containerSize.width / imageSize.width, containerSize.height / imageSize.height)
        let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: (containerSize.width - scaledSize.width) / 2,
            y: (containerSize.height - scaledSize.height) / 2,
            width: scaledSize.width,
            height: scaledSize.height
        )
    }

    private var previewControls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                thumbnail(asset: AppSampleAssets.messyDesk, isSelected: true)
                thumbnail(asset: AppSampleAssets.clutteredStudy, isSelected: false)
                Spacer()
            }
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(SmartPawStyle.blue, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("AR扫描就绪").font(FigmaFont.medium(11))
                    Text("视频扫描将被重建为3D网格。")
                        .font(FigmaFont.regular(9))
                        .foregroundStyle(SmartPawStyle.brown.opacity(0.58))
                }
                Spacer()
            }.padding(10).background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            Button { stage = .confirmed } label: {
                Text("确认并识别物品 →")
                    .font(FigmaFont.semibold(13))
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    private var confirmedControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 9) {
                Text("🦝")
                    .font(.system(size: 21))
                Text("我检测到\(viewModel.scannedItems.count)个项目。请确认，然后帮我解决\(blindSpotItems.count)个不清楚的地方。")
                    .font(FigmaFont.regular(10))
                    .foregroundStyle(SmartPawStyle.brown.opacity(0.76))
                    .lineSpacing(3)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text("需要你的帮助")
                    .font(FigmaFont.medium(10))
                ReviewHelpRow(text: "镜子后方 · 遮挡 — 请重新拍摄")
                ReviewHelpRow(text: "框内物品 · 光线不足 — 请描述物品")
            }
            .padding(12)
            .foregroundStyle(SmartPawStyle.brown.opacity(0.74))
            .background(SmartPawStyle.orange.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(SmartPawStyle.orange.opacity(0.26), lineWidth: 1)
            }

            HStack {
                Text("识别到的物品")
                    .font(FigmaFont.medium(10))
                Spacer()
                Button { sheet = .library } label: {
                    Label("添加", systemImage: "plus")
                        .font(FigmaFont.regular(9))
                        .padding(.horizontal, 9)
                        .frame(height: 25)
                        .background(.white, in: Capsule())
                }
                .buttonStyle(.plain)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 7)], alignment: .leading, spacing: 7) {
                ForEach(viewModel.scannedItems) { item in
                    Button { viewModel.toggleScannedItem(item.id) } label: {
                        HStack(spacing: 4) {
                            Image(systemName: itemIcon(item))
                            Text(item.name).lineLimit(1)
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .font(FigmaFont.regular(9))
                        .padding(.horizontal, 9)
                        .frame(height: 28)
                        .background(.white, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            Button { sheet = .organize } label: {
                Text("先解决这\(blindSpotItems.count)个盲点")
                    .font(FigmaFont.medium(11))
                    .foregroundStyle(SmartPawStyle.brown.opacity(0.48))
                    .frame(maxWidth: .infinity, minHeight: 42)
                    .background(SmartPawStyle.tan.opacity(0.72), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(SmartPawStyle.brown)
    }

    private func itemIcon(_ item: DetectedItem) -> String {
        switch item.category {
        case .books: "book.closed.fill"
        case .electronics: "laptopcomputer"
        case .stationery: "pencil"
        case .clothes: "tshirt.fill"
        case .toys: "teddybear.fill"
        case .trash: "trash.fill"
        case .tools: "wrench.and.screwdriver.fill"
        }
    }

    private func thumbnail(asset: String, isSelected: Bool) -> some View {
        StorageImageView(url: nil, assetName: asset, fallbackProgress: 0)
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(isSelected ? SmartPawStyle.orange : .clear, lineWidth: 2)
            }
    }

    private var organizeSheet: some View { VStack(spacing: 14) { Text("标记收纳方案").font(FigmaFont.semibold(16)); HStack(spacing: 12) { Button { sheet = nil; dismiss() } label: { actionTile("重新拍摄", icon: "camera") }; Button { viewModel.focusZone = "已标记收纳区域"; sheet = nil } label: { actionTile("标记收纳区", icon: "pencil") } }; Button("取消") { sheet = nil }.buttonStyle(.bordered) }.padding(20).presentationDetents([.height(260)]) }
    private var librarySheet: some View { VStack(alignment: .leading, spacing: 14) { HStack { Text("从物品库添加").font(FigmaFont.semibold(16)); Spacer(); Button("新物品") { sheet = .manual }.buttonStyle(.borderedProminent) }; Text("分类").font(FigmaFont.medium(11)); LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) { ForEach(ItemCategory.allCases) { category in Button { viewModel.addManualItem(name: category.rawValue, category: category); sheet = nil } label: { Label(category.rawValue, systemImage: categoryIcon(category)).font(FigmaFont.regular(11)).frame(maxWidth: .infinity, minHeight: 44).background(SmartPawStyle.tan.opacity(0.45), in: RoundedRectangle(cornerRadius: 10, style: .continuous)) }.buttonStyle(.plain) } }; Spacer() }.padding(20).presentationDetents([.medium]) }
    private var manualSheet: some View { VStack(alignment: .leading, spacing: 14) { Text("添加新物品").font(FigmaFont.semibold(16)); TextField("例如：咖啡杯、宠物玩具…", text: $manualName).textFieldStyle(.roundedBorder); Picker("分类", selection: $manualCategory) { ForEach(ItemCategory.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.menu); HStack { Button("取消") { sheet = nil }.buttonStyle(.bordered); Spacer(); Button("添加物品") { viewModel.addManualItem(name: manualName, category: manualCategory); manualName = ""; sheet = nil }.buttonStyle(.borderedProminent).disabled(manualName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) } }.padding(20).presentationDetents([.height(270)]) }
    private func actionTile(_ title: String, icon: String) -> some View { VStack(spacing: 8) { Image(systemName: icon); Text(title).font(FigmaFont.medium(11)) }.foregroundStyle(SmartPawStyle.orange).frame(maxWidth: .infinity, minHeight: 78).background(SmartPawStyle.tan.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous)) }
    private func categoryIcon(_ category: ItemCategory) -> String { switch category { case .books: "books.vertical"; case .electronics: "laptopcomputer"; case .stationery: "pencil"; case .clothes: "tshirt"; case .toys: "gamecontroller"; case .trash: "trash"; case .tools: "wrench.and.screwdriver" } }
}

private struct ScanCountdownHUD: View {
    let deadline: Date?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.2)) { timeline in
            let remaining = remainingSeconds(at: timeline.date)
            VStack(spacing: 10) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.05)
                Text(remaining > 0 ? "AR 识别中 \(remaining)" : "整理结果中")
                    .font(FigmaFont.bold(17))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                Text("请保持镜头稳定")
                    .font(FigmaFont.semibold(12))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Color.black.opacity(0.48), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.16), lineWidth: 1)
            }
            .accessibilityLabel(remaining > 0 ? "AR 识别中，剩余 \(remaining) 秒" : "正在整理识别结果")
        }
    }

    private func remainingSeconds(at date: Date) -> Int {
        guard let deadline else { return 0 }
        return max(0, Int(ceil(deadline.timeIntervalSince(date))))
    }
}

private struct ReviewHelpRow: View {
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(SmartPawStyle.orange)
                .frame(width: 4, height: 4)
            Text(text)
                .font(FigmaFont.regular(9))
                .lineLimit(1)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(SmartPawStyle.brown.opacity(0.42))
        }
    }
}

private struct ReviewBlindSpotOverlay: View {
    let item: DetectedItem
    let index: Int
    let imageRect: CGRect
    let visibleRect: CGRect
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(SmartPawStyle.orange.opacity(0.12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(
                                SmartPawStyle.orange,
                                style: StrokeStyle(lineWidth: 2, dash: [5, 4])
                            )
                    }
                Label(blindSpotTitle, systemImage: "exclamationmark.triangle.fill")
                    .font(FigmaFont.medium(9))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .frame(height: 27)
                    .background(SmartPawStyle.orange, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .offset(x: 5, y: 5)
            }
        }
        .buttonStyle(.plain)
        .frame(width: spotRect.width, height: spotRect.height)
        .position(x: spotRect.midX, y: spotRect.midY)
        .accessibilityLabel("需要确认：\(blindSpotTitle)")
    }

    private var blindSpotTitle: String {
        index == 0 ? "框内物品" : "镜子后方"
    }

    private var spotRect: CGRect {
        let source = sourceRect
        let width = min(max(source.width * 1.08, 118), 138)
        let height = min(max(source.height * 1.10, 72), 96)
        let bounds = visibleRect.insetBy(dx: 10, dy: 12)
        let centerX = min(max(source.midX, bounds.minX + width / 2), bounds.maxX - width / 2)
        let centerY = min(max(source.midY, bounds.minY + height / 2), bounds.maxY - height / 2)
        return CGRect(x: centerX - width / 2, y: centerY - height / 2, width: width, height: height)
    }

    private var sourceRect: CGRect {
        if let mask = item.arMask,
           let minX = mask.points.map(\.x).min(),
           let maxX = mask.points.map(\.x).max(),
           let minY = mask.points.map(\.y).min(),
           let maxY = mask.points.map(\.y).max(),
           maxX > minX,
           maxY > minY {
            return CGRect(
                x: imageRect.minX + CGFloat(minX) * imageRect.width,
                y: imageRect.minY + CGFloat(minY) * imageRect.height,
                width: CGFloat(maxX - minX) * imageRect.width,
                height: CGFloat(maxY - minY) * imageRect.height
            )
        }
        if let hint = item.arHint {
            return CGRect(
                x: imageRect.minX + CGFloat(hint.x - hint.width / 2) * imageRect.width,
                y: imageRect.minY + CGFloat(hint.y - hint.height / 2) * imageRect.height,
                width: CGFloat(hint.width) * imageRect.width,
                height: CGFloat(hint.height) * imageRect.height
            )
        }
        return CGRect(x: visibleRect.midX - 52, y: visibleRect.midY - 36, width: 104, height: 72)
    }
}

private struct CameraViewfinderPlaceholder: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.12, blue: 0.13),
                    Color(red: 0.22, green: 0.19, blue: 0.15)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 18) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 54, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.88))
                Text("准备打开相机")
                    .font(FigmaFont.semibold(17))
                    .foregroundStyle(.white)
                Text("真机会显示实时镜头，模拟器显示取景占位")
                    .font(FigmaFont.medium(12))
                    .foregroundStyle(.white.opacity(0.72))
            }

            ViewfinderCorner()
                .stroke(.white.opacity(0.72), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .padding(42)
        }
    }
}

private struct ViewfinderCorner: Shape {
    func path(in rect: CGRect) -> Path {
        let corner: CGFloat = min(rect.width, rect.height) * 0.18
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + corner))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + corner, y: rect.minY))
        path.move(to: CGPoint(x: rect.maxX - corner, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + corner))
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - corner))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - corner, y: rect.maxY))
        path.move(to: CGPoint(x: rect.minX + corner, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - corner))
        return path
    }
}

private struct ScanDetectionMask: View {
    let item: DetectedItem
    let mask: ARMask
    let imageRect: CGRect

    var body: some View {
        ARMaskOverlay(mask: mask, color: maskColor.opacity(item.isSelected ? 0.74 : 0.46))
            .frame(width: imageRect.width, height: imageRect.height)
            .position(x: imageRect.midX, y: imageRect.midY)
    }

    private var maskColor: Color {
        return switch item.category {
        case .books: SmartPawStyle.blue
        case .electronics: SmartPawStyle.mint
        case .stationery: .pink
        case .clothes: .cyan
        case .toys: .purple
        case .trash: SmartPawStyle.orange
        case .tools: .yellow
        }
    }
}

private struct ScanDetectionBox: View {
    let item: DetectedItem
    let hint: ARHint
    let imageRect: CGRect

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .stroke(SmartPawStyle.mint.opacity(item.isSelected ? 0.96 : 0.54), style: StrokeStyle(lineWidth: 2.2, dash: [7, 5]))
            .frame(width: CGFloat(hint.width) * imageRect.width, height: CGFloat(hint.height) * imageRect.height)
            .position(
                x: imageRect.minX + CGFloat(hint.x) * imageRect.width,
                y: imageRect.minY + CGFloat(hint.y) * imageRect.height
            )
            .accessibilityLabel("识别范围 \(item.name)")
    }
}

private struct ScanItemNameTag: View {
    let item: DetectedItem
    let mask: ARMask?
    let imageRect: CGRect
    let visibleRect: CGRect
    let isSelected: Bool
    var labelOffset: CGPoint = .zero
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            Label(item.name, systemImage: iconName)
                .labelStyle(.titleAndIcon)
                .font(FigmaFont.semibold(12))
                .lineLimit(1)
                .minimumScaleFactor(0.76)
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .frame(width: 100, height: 30)
                .background(maskColor.opacity(isSelected ? 0.94 : 0.68), in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(.white.opacity(isSelected ? 0.86 : 0.36), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.22), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .position(labelPosition)
        .opacity(isSelected ? 1 : 0.58)
        .accessibilityLabel("识别到\(item.name)")
    }

    private var labelPosition: CGPoint {
        let rect = itemRect
        let labelHalfWidth: CGFloat = 50
        // Pin the tag to the mask's upper-left corner so each label has an
        // unambiguous visual owner, even when several masks overlap nearby.
        let desiredX = rect.minX + labelHalfWidth + 10
        let desiredY = rect.minY + 20 + labelOffset.y
        return CGPoint(
            x: min(max(desiredX, visibleRect.minX + labelHalfWidth + 14), visibleRect.maxX - labelHalfWidth - 14),
            y: min(max(desiredY, visibleRect.minY + 36), visibleRect.maxY - 152)
        )
    }

    private var itemRect: CGRect {
        let xs = mask?.points.map(\.x) ?? []
        let ys = mask?.points.map(\.y) ?? []
        if let minX = xs.min(),
           let maxX = xs.max(),
           let minY = ys.min(),
           let maxY = ys.max(),
           maxX > minX,
           maxY > minY {
            return CGRect(
                x: imageRect.minX + CGFloat(minX) * imageRect.width,
                y: imageRect.minY + CGFloat(minY) * imageRect.height,
                width: CGFloat(maxX - minX) * imageRect.width,
                height: CGFloat(maxY - minY) * imageRect.height
            )
        }

        if let hint = item.arHint {
            return CGRect(
                x: imageRect.minX + CGFloat(hint.x - hint.width / 2) * imageRect.width,
                y: imageRect.minY + CGFloat(hint.y - hint.height / 2) * imageRect.height,
                width: CGFloat(hint.width) * imageRect.width,
                height: CGFloat(hint.height) * imageRect.height
            )
        }
        return CGRect(x: imageRect.midX - 1, y: imageRect.midY - 1, width: 2, height: 2)
    }

    private var maskColor: Color {
        return switch item.category {
        case .books: SmartPawStyle.blue
        case .electronics: SmartPawStyle.mint
        case .stationery: .pink
        case .clothes: .cyan
        case .toys: .purple
        case .trash: SmartPawStyle.orange
        case .tools: .yellow
        }
    }

    private var iconName: String {
        if item.name.contains("手机") { return "iphone" }
        if item.name.contains("电脑") { return "laptopcomputer" }
        return switch item.category {
        case .books: "book.closed"
        case .electronics: "desktopcomputer"
        case .stationery: "pencil.and.ruler"
        case .clothes: "tshirt"
        case .toys: "shippingbox"
        case .trash: "trash"
        case .tools: "tray.full"
        }
    }
}

private struct CaptureActions: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Binding var selectedPhotoItem: PhotosPickerItem?
    @Binding var isShowingRoomScanner: Bool
    let selectedMode: CaptureScanMode
    @Binding var multiCameraImages: [UIImage]
    @Binding var isARScanRecording: Bool
    @ObservedObject var cameraModel: CaptureCameraModel
    let onFinished: () -> Void
    let onMultiCameraFinished: () -> Void

    var body: some View {
        VStack(spacing: 7) {
            HStack(alignment: .center, spacing: 12) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    CaptureThumbnailButton(images: multiCameraImages)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("从相册导入照片")

                Spacer(minLength: 0)

                Button {
                    selectedMode == .arScan ? toggleARScanRecording() : captureStillPhoto()
                } label: {
                    ZStack {
                        Circle()
                            .stroke(.white, lineWidth: 6)
                            .frame(width: 62, height: 62)
                        Circle()
                            .fill(selectedMode == .arScan ? SmartPawStyle.scanRed : SmartPawStyle.brown.opacity(0.2))
                            .frame(width: isARScanRecording ? 20 : 46, height: isARScanRecording ? 20 : 46)
                            .clipShape(RoundedRectangle(cornerRadius: isARScanRecording ? 5 : 24, style: .continuous))
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isScanning || cameraModel.isStillCaptureInProgress)
                    .accessibilityLabel(selectedMode == .arScan ? (isARScanRecording ? "停止扫描录像" : "开始扫描录像") : "拍摄多镜头素材")

                Spacer(minLength: 0)

                Button {
                    finishCurrentScan()
                } label: {
                    Label("完成", systemImage: "checkmark")
                        .font(FigmaFont.medium(9))
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .frame(width: 62, height: 34)
                        .background(SmartPawStyle.orange, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isScanning || cameraModel.isStillCaptureInProgress || isARScanRecording)
                .accessibilityLabel(selectedMode == .multiCamera ? "进入多镜头预览" : "完成扫描")
            }

            Text(selectedMode == .arScan ? (isARScanRecording ? "在拍摄的过程中，进行3D扫描" : "在拍摄的过程中，进行3D扫描") : "继续从不同角度拍摄，下一步 → 完成")
                .font(FigmaFont.regular(7))
                .foregroundStyle(SmartPawStyle.brown.opacity(0.42))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 9)
        // Figma uses a stable white control surface. A system material changes
        // contrast with the camera feed and makes the action row drift on-device.
        .background(.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.82), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 16, y: 7)
    }

    private func captureStillPhoto() {
        if selectedMode == .multiCamera { captureMultiCameraFrame(); return }
        cameraModel.beginStillCapture()
        cameraModel.capturePhoto { image in
            guard let image else {
                cameraModel.endStillCapture()
                viewModel.showMessage("当前设备无法读取相机画面，请用相册导入照片。")
                return
            }
            viewModel.setCapturedImage(image)
            cameraModel.endStillCapture()
        }
    }

    private func finishCurrentScan() {
        if selectedMode == .multiCamera {
            finishMultiCameraCapture()
            return
        }
        guard !viewModel.scannedItems.isEmpty else {
            viewModel.showMessage("请先点击红色录像按钮完成一次扫描。")
            return
        }
        onFinished()
    }

    private func toggleARScanRecording() {
        guard !isARScanRecording else {
            isARScanRecording = false
            scanRecordedFrame()
            return
        }
        isARScanRecording = true
        cameraModel.beginScanFeedback(duration: 20)
        viewModel.showMessage("已开始扫描，请缓慢移动镜头覆盖空间。")
    }

    private func scanRecordedFrame() {
        cameraModel.beginStillCapture()
        cameraModel.capturePhoto { image in
            guard let image else {
                cameraModel.endScanFeedback()
                cameraModel.endStillCapture()
                viewModel.showMessage("无法读取扫描画面，请重新录制。")
                return
            }
            Task {
                await viewModel.scanImage(image)
                await MainActor.run {
                    cameraModel.endScanFeedback()
                    cameraModel.endStillCapture()
                }
            }
        }
    }

    private var multiCameraHint: String {
        multiCameraImages.count < 2
            ? "请从不同角度拍摄空间（\(multiCameraImages.count)/2）"
            : "两张素材准备就绪，点击完成进入预览"
    }

    private func captureMultiCameraFrame() {
        guard multiCameraImages.count < 2 else {
            viewModel.showMessage("两张多镜头素材已经准备好了，可以进入预览。")
            return
        }
        cameraModel.beginStillCapture()
        cameraModel.capturePhoto { image in
            guard let image else {
                cameraModel.endStillCapture()
                viewModel.showMessage("无法读取当前相机画面，请再试一次。")
                return
            }
            multiCameraImages.append(image)
            cameraModel.endStillCapture()
            viewModel.showMessage(multiCameraImages.count == 2 ? "两张素材已准备就绪。" : "已拍好第 1 张，请换一个角度再拍 1 张。")
        }
    }

    private func finishMultiCameraCapture() {
        guard multiCameraImages.count == 2 else {
            viewModel.showMessage("还需补拍 \(2 - multiCameraImages.count) 个角度后才能生成多镜头结果。")
            return
        }
        onMultiCameraFinished()
    }

    private func captureFallbackAndReview() {
        Task {
            await viewModel.scanBundledSample(assetName: AppSampleAssets.messyDesk)
            await MainActor.run {
                onFinished()
            }
        }
    }
}

private struct MultiCameraPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: AppViewModel
    let images: [UIImage]
    let onRecognitionFinished: () -> Void
    @State private var selectedIndex = 0
    @State private var isRecognizing = false

    var body: some View {
        ZStack {
            SmartPawStyle.canvas.ignoresSafeArea()
            VStack(spacing: 18) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(SmartPawStyle.brown)
                            .frame(width: 42, height: 42)
                            .background(.white, in: Circle())
                    }
                    Spacer()
                    VStack(spacing: 3) {
                        Text("预览结果")
                            .font(FigmaFont.semibold(18))
                            .foregroundStyle(SmartPawStyle.brown)
                        Text("2 张素材准备就绪")
                            .font(FigmaFont.regular(12))
                            .foregroundStyle(SmartPawStyle.brown.opacity(0.56))
                    }
                    Spacer()
                    Color.clear.frame(width: 42, height: 42)
                }

                if let image = images[safe: selectedIndex] {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 370)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }

                HStack(spacing: 10) {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                        Button { selectedIndex = index } label: {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 58, height: 58)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(selectedIndex == index ? SmartPawStyle.orange : .clear, lineWidth: 3)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 12) {
                    Image(systemName: "cube.transparent")
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(SmartPawStyle.brown.opacity(0.76), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("多镜头扫描数据")
                            .font(FigmaFont.semibold(14))
                            .foregroundStyle(SmartPawStyle.brown)
                        Text("两个角度将合并为一次空间识别结果")
                            .font(FigmaFont.regular(12))
                            .foregroundStyle(SmartPawStyle.brown.opacity(0.58))
                    }
                    Spacer(minLength: 0)
                }
                .padding(13)
                .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                Spacer(minLength: 0)

                Button {
                    Task {
                        isRecognizing = true
                        await viewModel.scanImages(images)
                        isRecognizing = false
                        onRecognitionFinished()
                    }
                } label: {
                    Label(isRecognizing ? "识别中" : "开始识别", systemImage: isRecognizing ? "hourglass" : "sparkles")
                        .frame(maxWidth: .infinity, minHeight: 54)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isRecognizing)
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 24)
        }
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private struct CaptureThumbnailButton: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let images: [UIImage]

    var body: some View {
        VStack(spacing: 3) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let image = images.last ?? viewModel.capturedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(.white.opacity(0.74))
                            .overlay {
                                Image(systemName: "photo")
                                    .font(FigmaFont.medium(10))
                                    .foregroundStyle(SmartPawStyle.brown.opacity(0.42))
                            }
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                if !images.isEmpty || viewModel.capturedImage != nil {
                    Image(systemName: "plus")
                        .font(FigmaFont.semibold(10))
                        .foregroundStyle(.white)
                        .frame(width: 16, height: 16)
                        .background(Color.black.opacity(0.45), in: Circle())
                        .offset(x: 5, y: -5)
                }
            }
            .frame(width: 50, height: 44)

            Text("\(clipCount)\nclip")
                .font(FigmaFont.medium(6))
                .multilineTextAlignment(.center)
                .foregroundStyle(SmartPawStyle.brown.opacity(0.72))
                .frame(width: 28, height: 21)
                .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .frame(width: 54, height: 68)
    }

    private var clipCount: Int {
        max(images.count, viewModel.capturedImage == nil ? 0 : 1)
    }
}

private struct CaptureCircleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(SmartPawStyle.brown)
            .background(.white.opacity(configuration.isPressed ? 0.72 : 0.92), in: Circle())
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private struct CaptureModeButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isSelected ? SmartPawStyle.brown : .white.opacity(0.88))
            .background(isSelected ? .white.opacity(0.94) : .clear, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private final class CaptureCameraModel: NSObject, ObservableObject, @unchecked Sendable {
    @Published private(set) var items: [DetectedItem] = []
    @Published private(set) var isRunning = false
    @Published private(set) var isRecognizing = false
    @Published private(set) var canShowLiveCamera = false
    @Published private(set) var statusText = "相机"
    @Published private(set) var scanFeedbackDeadline: Date?
    @Published private(set) var isStillCaptureInProgress = false

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "SmartPaw.capture.camera.session")
    private let videoQueue = DispatchQueue(label: "SmartPaw.capture.camera.video")
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let ciContext = CIContext()
    private var didConfigureSession = false
    private var isLiveRecognitionEnabled = true
    private var isFrameProcessing = false
    private var lastScanDate = Date.distantPast
    private var recognitionGeneration = 0
    private var lastRecognizedItems: [DetectedItem] = []
    private var pendingRecognizedItems: [DetectedItem] = []
    private var consecutiveConsistentFrames = 0
    private var latestFrameImage: UIImage?
    private var pendingPhotoCompletion: ((UIImage?) -> Void)?

    func start() {
        #if DEBUG
        if CommandLine.arguments.contains("-SmartPawAutoVisionScan")
            || CommandLine.arguments.contains("-SmartPawAutoCaptureSample") {
            markUnavailable("测试图片")
            return
        }
        #endif
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    granted ? self?.configureAndStart() : self?.markUnavailable("未授权相机")
                }
            }
        case .denied, .restricted:
            markUnavailable("未授权相机")
        @unknown default:
            markUnavailable("相机不可用")
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
            DispatchQueue.main.async {
                self.isRunning = false
                self.statusText = "相机"
            }
        }
    }

    func setLiveRecognitionEnabled(_ enabled: Bool) {
        isLiveRecognitionEnabled = enabled
        if !enabled {
            DispatchQueue.main.async { [weak self] in
                self?.isRecognizing = false
                self?.pendingRecognizedItems = []
                self?.consecutiveConsistentFrames = 0
            }
        }
    }

    func beginStillCapture() {
        recognitionGeneration += 1
        isStillCaptureInProgress = true
        isRecognizing = false
        pendingRecognizedItems = []
        consecutiveConsistentFrames = 0
    }

    func endStillCapture() {
        isStillCaptureInProgress = false
    }

    func beginScanFeedback(duration: TimeInterval = 3) {
        scanFeedbackDeadline = Date().addingTimeInterval(duration)
    }

    func endScanFeedback() {
        scanFeedbackDeadline = nil
    }

    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        guard canShowLiveCamera else {
            completion(latestFrameImage)
            return
        }
        pendingPhotoCompletion = completion
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    private func configureAndStart() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.didConfigureSession {
                guard self.configureSession() else {
                    DispatchQueue.main.async { self.markUnavailable("无可用镜头") }
                    return
                }
                self.didConfigureSession = true
            }
            if !self.session.isRunning {
                self.session.startRunning()
            }
            DispatchQueue.main.async {
                self.canShowLiveCamera = true
                self.isRunning = self.session.isRunning
                self.statusText = self.session.isRunning ? "REC 0:03" : "相机"
            }
        }
    }

    private func configureSession() -> Bool {
        session.beginConfiguration()
        session.sessionPreset = .photo
        defer { session.commitConfiguration() }

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input)
        else { return false }
        session.addInput(input)

        guard session.canAddOutput(photoOutput), session.canAddOutput(videoOutput) else { return false }
        session.addOutput(photoOutput)

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        session.addOutput(videoOutput)
        return true
    }

    private func markUnavailable(_ text: String) {
        canShowLiveCamera = false
        isRunning = false
        isRecognizing = false
        scanFeedbackDeadline = nil
        statusText = text
    }

    private func image(from sampleBuffer: CMSampleBuffer) -> UIImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        return image(from: pixelBuffer)
    }

    private func image(from pixelBuffer: CVPixelBuffer) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer).oriented(.right)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    private func scanFrame(_ image: UIImage) {
        let generation = recognitionGeneration
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.isStillCaptureInProgress, generation == self.recognitionGeneration else { return }
            self.isRecognizing = true
            self.beginScanFeedback(duration: 1.5)
        }
        Task.detached(priority: .userInitiated) { [weak self] in
            let results = await YOLOSegmentationScanService().scanLiveImage(image)
            DispatchQueue.main.async {
                guard let self else { return }
                guard generation == self.recognitionGeneration, !self.isStillCaptureInProgress else {
                    self.isRecognizing = false
                    self.endScanFeedback()
                    return
                }
                // An overlay must agree with the immediately preceding frame
                // before it is drawn. This removes one-frame masks caused by
                // motion blur, autofocus and partial occlusion.
                if !results.isEmpty {
                    if Self.hasConsistentCandidate(in: results, comparedTo: self.pendingRecognizedItems) {
                        self.consecutiveConsistentFrames += 1
                    } else {
                        self.pendingRecognizedItems = results
                        self.consecutiveConsistentFrames = 1
                    }

                    // Draw the first valid result immediately. Later matching
                    // frames replace it, keeping the overlay responsive while
                    // still damping unstable detections.
                    if self.items.isEmpty || self.consecutiveConsistentFrames >= 2 {
                        self.lastRecognizedItems = results
                        self.items = results
                    }
                } else if !self.lastRecognizedItems.isEmpty {
                    self.items = self.lastRecognizedItems
                }
                self.isRecognizing = false
                self.endScanFeedback()
            }
            self?.videoQueue.async {
                self?.isFrameProcessing = false
            }
        }
    }

    private static func hasConsistentCandidate(in current: [DetectedItem], comparedTo previous: [DetectedItem]) -> Bool {
        current.contains { candidate in
            guard let currentHint = candidate.arHint else { return false }
            return previous.contains { prior in
                guard prior.category == candidate.category, let previousHint = prior.arHint else { return false }
                return hintIoU(currentHint, previousHint) >= 0.34
            }
        }
    }

    private static func hintIoU(_ lhs: ARHint, _ rhs: ARHint) -> Double {
        let left = CGRect(x: lhs.x - lhs.width / 2, y: lhs.y - lhs.height / 2, width: lhs.width, height: lhs.height)
        let right = CGRect(x: rhs.x - rhs.width / 2, y: rhs.y - rhs.height / 2, width: rhs.width, height: rhs.height)
        let overlap = left.intersection(right)
        guard !overlap.isNull else { return 0 }
        let overlapArea = overlap.width * overlap.height
        let unionArea = left.width * left.height + right.width * right.height - overlapArea
        return unionArea > 0 ? Double(overlapArea / unionArea) : 0
    }
}

extension CaptureCameraModel: AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let image = image(from: sampleBuffer) else { return }
        latestFrameImage = image

        guard isLiveRecognitionEnabled,
              !isStillCaptureInProgress,
              Date().timeIntervalSince(lastScanDate) > 0.4,
              !isFrameProcessing
        else { return }
        lastScanDate = Date()
        isFrameProcessing = true
        scanFrame(image)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let image: UIImage?
        if error == nil,
           let data = photo.fileDataRepresentation(),
           let captured = UIImage(data: data) {
            image = captured
        } else {
            image = latestFrameImage
        }
        let completion = pendingPhotoCompletion
        pendingPhotoCompletion = nil
        DispatchQueue.main.async {
            completion?(image)
        }
    }
}

private struct EmbeddedCameraView: UIViewRepresentable {
    @ObservedObject var cameraModel: CaptureCameraModel

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.previewLayer.session = cameraModel.session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        uiView.previewLayer.session = cameraModel.session
    }
}

private final class CameraPreviewUIView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
        if let connection = previewLayer.connection,
           connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
    }
}

private struct RoomScannerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: AppViewModel
    @StateObject private var controller = RoomCaptureController()

    var body: some View {
        NavigationStack {
            Group {
                if RoomCaptureSession.isSupported {
                    RoomCaptureContainer(controller: controller) { categories in
                        viewModel.importRoomPlanObjects(categories)
                        dismiss()
                    }
                } else {
                    VStack(spacing: 14) {
                        Image(systemName: "cube.transparent")
                            .font(.system(size: 46, weight: .semibold))
                            .foregroundStyle(SmartPawStyle.orange)
                        Text("当前设备不支持 RoomPlan")
                            .font(.headline)
                            .foregroundStyle(SmartPawStyle.brown)
                        Text("RoomPlan 需要支持空间扫描的真机。你仍然可以使用相册导入或相机拍摄完成真实物品识别。")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    }
                    .padding()
                }
            }
            .navigationTitle("空间扫描")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(controller.isProcessing ? "处理中" : "完成") {
                        if RoomCaptureSession.isSupported {
                            controller.stop()
                        } else {
                            dismiss()
                        }
                    }
                    .disabled(controller.isProcessing)
                }
            }
        }
        .alert("空间扫描失败", isPresented: Binding(
            get: { controller.errorMessage != nil },
            set: { if !$0 { controller.errorMessage = nil } }
        )) {
            Button("知道了") { controller.errorMessage = nil }
        } message: {
            Text(controller.errorMessage ?? "请重新扫描。")
        }
    }
}

@MainActor
private final class RoomCaptureController: ObservableObject {
    weak var captureView: RoomCaptureView?
    @Published var isProcessing = false
    @Published var errorMessage: String?

    func stop() {
        guard captureView != nil else { return }
        isProcessing = true
        captureView?.captureSession.stop()
    }
}

private struct RoomCaptureContainer: UIViewRepresentable {
    @ObservedObject var controller: RoomCaptureController
    let onCaptured: ([String]) -> Void

    func makeUIView(context: Context) -> RoomCaptureView {
        let view = RoomCaptureView(frame: .zero)
        view.captureSession.delegate = context.coordinator
        controller.captureView = view
        let configuration = RoomCaptureSession.Configuration()
        view.captureSession.run(configuration: configuration)
        return view
    }

    func updateUIView(_ uiView: RoomCaptureView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller, onCaptured: onCaptured)
    }

    static func dismantleUIView(_ uiView: RoomCaptureView, coordinator: Coordinator) {
        uiView.captureSession.stop()
    }

    final class Coordinator: NSObject, RoomCaptureSessionDelegate {
        private weak var controller: RoomCaptureController?
        private let onCaptured: ([String]) -> Void

        init(controller: RoomCaptureController, onCaptured: @escaping ([String]) -> Void) {
            self.controller = controller
            self.onCaptured = onCaptured
        }

        func captureSession(_ session: RoomCaptureSession, didEndWith data: CapturedRoomData, error: Error?) {
            guard error == nil else {
                Task { @MainActor in
                    controller?.isProcessing = false
                    controller?.errorMessage = error?.localizedDescription ?? "空间扫描未能完成。"
                }
                return
            }
            Task {
                do {
                    let room = try await RoomBuilder(options: [.beautifyObjects]).capturedRoom(from: data)
                    await MainActor.run {
                        controller?.isProcessing = false
                        onCaptured(room.objects.map { String(describing: $0.category) })
                    }
                } catch {
                    await MainActor.run {
                        controller?.isProcessing = false
                        controller?.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
}

struct SecondaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(SmartPawStyle.brown)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                configuration.isPressed ? SmartPawStyle.tan.opacity(0.7) : .white.opacity(0.78),
                in: SmartPawStyle.cardShape
            )
            .overlay {
                SmartPawStyle.cardShape.stroke(SmartPawStyle.hairline, lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    let onImagePicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked, dismiss: dismiss)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImagePicked: (UIImage) -> Void
        let dismiss: DismissAction

        init(onImagePicked: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onImagePicked = onImagePicked
            self.dismiss = dismiss
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImagePicked(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}
