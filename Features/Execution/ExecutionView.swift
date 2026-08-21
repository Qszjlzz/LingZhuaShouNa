import ARKit
import PhotosUI
import RealityKit
import SwiftUI

struct ExecutionView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var selectedAfterPhotoItem: PhotosPickerItem?
    @State private var isShowingAfterCamera = false
    @State private var isShowingLiveAR = false
    @State private var isShowingTools = false
    @State private var isShowingCompletion = false
    let plan: StoragePlan
    var onFinished: (() -> Void)?

    init(plan: StoragePlan, onFinished: (() -> Void)? = nil) {
        self.plan = plan
        self.onFinished = onFinished
    }

    var body: some View {
        ScreenBackground(title: "执行整理", subtitle: "跟着步骤完成当前空间") {
            ExecutionSummaryCard(plan: plan)
            ExecutionFocusCard(plan: plan)
            ExecutionZoneSelector(plan: plan)

            ARGuidePreview(plan: plan)
                .frame(height: 260)

            Button {
                isShowingLiveAR = true
            } label: {
                Label("启动实时 AR 引导", systemImage: "arkit")
            }
            .buttonStyle(PrimaryButtonStyle())

            Card {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("所需工具")
                            .font(.headline)
                            .foregroundStyle(SmartPawStyle.brown)
                        Spacer()
                        Button("查看全部") { isShowingTools = true }
                            .font(.caption.weight(.bold))
                            .foregroundStyle(SmartPawStyle.orange)
                    }
                    FlowLayout(items: plan.toolList)
                }
            }

            ForEach(plan.steps) { step in
                StepCard(step: step)
            }

            if plan.steps.allSatisfy({ $0.status == .done }) {
                CompletionPhotoCard(
                    selectedPhotoItem: $selectedAfterPhotoItem,
                    isShowingCamera: $isShowingAfterCamera
                )
            }
        }
        .onChange(of: selectedAfterPhotoItem) { _, item in
            guard let item else { return }
            Task { await loadAfterPhoto(item) }
        }
        .sheet(isPresented: $isShowingAfterCamera) {
            CameraPicker { image in
                viewModel.finishActivePlan(afterImage: image)
                isShowingCompletion = true
            }
        }
        .sheet(isPresented: $isShowingLiveAR) {
            LiveARGuideSheet(plan: plan)
        }
        .sheet(isPresented: $isShowingTools) {
            ToolListSheet(tools: plan.toolList)
        }
        .sheet(isPresented: $isShowingCompletion) {
            PlanCompletionSheet(onReturnToSpace: {
                isShowingCompletion = false
                if let onFinished {
                    onFinished()
                } else {
                    viewModel.selectedTab = .space
                }
            })
        }
        .onAppear {
            #if DEBUG
            if CommandLine.arguments.contains("-SmartPawAutoShowLiveAR") {
                isShowingLiveAR = true
            }
            #endif
        }
    }

    private func loadAfterPhoto(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage.downsampled(data: data)
            else {
                viewModel.showMessage("无法读取这张完成照，请换一张图片重试。")
                return
            }
            viewModel.finishActivePlan(afterImage: image)
            isShowingCompletion = true
        } catch {
            viewModel.showMessage("导入完成照失败：\(error.localizedDescription)")
        }
    }
}

private struct ExecutionFocusCard: View {
    let plan: StoragePlan

    private var currentStep: StorageStep? {
        plan.steps.first { $0.status == .active } ?? plan.steps.first { $0.status != .done }
    }

    private var completedCount: Int {
        plan.steps.filter { $0.status == .done }.count
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "scope")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(SmartPawStyle.orange, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text("当前整理焦点")
                    .font(FigmaFont.regular(11))
                    .foregroundStyle(SmartPawStyle.brown.opacity(0.56))
                Text(currentStep?.title ?? "整理已完成，拍摄完成照")
                    .font(FigmaFont.semibold(14))
                    .foregroundStyle(SmartPawStyle.brown)
                    .lineLimit(1)
                Text("已完成 \(completedCount) / \(max(1, plan.steps.count)) 步")
                    .font(FigmaFont.regular(10))
                    .foregroundStyle(SmartPawStyle.orange)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(SmartPawStyle.hairline, lineWidth: 1)
        }
    }
}

private struct PlanCompletionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: AppViewModel
    let onReturnToSpace: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image("FigmaCompletion")
                .resizable()
                .scaledToFit()
                .frame(width: 112, height: 112)
                .clipShape(Circle())

            VStack(spacing: 7) {
                Text("本次整理完成")
                    .font(FigmaFont.semibold(25))
                    .foregroundStyle(SmartPawStyle.brown)
                Text("成果已保存到空间档案，可以随时查看前后对比。")
                    .font(FigmaFont.regular(14))
                    .foregroundStyle(SmartPawStyle.brown.opacity(0.6))
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 10) {
                CompletionSheetMetric(value: "\(viewModel.completedCount)", label: "完成空间")
                CompletionSheetMetric(value: "\(viewModel.catalogItems.count)", label: "已归档物品")
                CompletionSheetMetric(value: "+50", label: "本次 XP")
            }

            Button {
                viewModel.shareLatestCompletion()
                dismiss()
                viewModel.selectedTab = .community
            } label: {
                Label("分享到社区", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(SecondaryActionButtonStyle())

            Button("回到空间", action: onReturnToSpace)
                .buttonStyle(PrimaryButtonStyle())
        }
        .padding(24)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

private struct CompletionSheetMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(FigmaFont.semibold(18))
                .foregroundStyle(SmartPawStyle.orange)
            Text(label)
                .font(FigmaFont.regular(11))
                .foregroundStyle(SmartPawStyle.brown.opacity(0.55))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 58)
        .background(SmartPawStyle.tan.opacity(0.34), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct ExecutionSummaryCard: View {
    let plan: StoragePlan

    var body: some View {
        Card {
            HStack(spacing: 14) {
                Image(systemName: "checklist")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(SmartPawStyle.brown, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                VStack(alignment: .leading, spacing: 5) {
                    Text(plan.summary)
                        .font(.headline.weight(.black))
                        .foregroundStyle(SmartPawStyle.brown)
                        .lineLimit(2)
                    Text("已完成 \(plan.steps.filter { $0.status == .done }.count) / \(plan.steps.count) 步")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Text("\(Int(plan.progress * 100))%")
                    .font(.title3.weight(.black))
                    .foregroundStyle(SmartPawStyle.orange)
            }
        }
    }
}

private struct ToolListSheet: View {
    @Environment(\.dismiss) private var dismiss
    let tools: [String]
    @State private var selectedTool: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "shippingbox.fill")
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(SmartPawStyle.brown, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("智能方案使用的收纳工具")
                                .font(.headline.weight(.black))
                                .foregroundStyle(SmartPawStyle.brown)
                            Text("标记已有工具，或查看适配的购买建议")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(SmartPawStyle.tan.opacity(0.55), in: SmartPawStyle.cardShape)

                    ForEach(tools, id: \.self) { tool in
                        Button { selectedTool = tool } label: {
                            HStack(spacing: 12) {
                                StorageImageView(url: nil, assetName: AppSampleAssets.clutteredStudy, fallbackProgress: 1)
                                    .frame(width: 72, height: 72)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(tool)
                                        .font(.subheadline.weight(.bold))
                                    Text("适合本次区域整理的基础工具")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("查看购买推荐")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(SmartPawStyle.orange)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                            }
                            .foregroundStyle(SmartPawStyle.brown)
                            .padding(10)
                            .background(.white, in: SmartPawStyle.cardShape)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .background(SmartPawStyle.canvas.ignoresSafeArea())
            .navigationTitle("所需工具")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .sheet(item: Binding(
                get: { selectedTool.map(ToolSelection.init) },
                set: { selectedTool = $0?.name }
            )) { tool in
                ToolRecommendationSheet(tool: tool.name)
            }
        }
    }
}

private struct ToolSelection: Identifiable {
    let name: String
    var id: String { name }
}

private struct ToolRecommendationSheet: View {
    @Environment(\.dismiss) private var dismiss
    let tool: String

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    StorageImageView(url: nil, assetName: AppSampleAssets.clutteredStudy, fallbackProgress: 1)
                        .frame(height: 250)
                        .clipShape(SmartPawStyle.cardShape)
                    Text(tool)
                        .font(.title2.weight(.black))
                        .foregroundStyle(SmartPawStyle.brown)
                    Text("用于把同类物品归位，减少台面上的零散视觉噪音。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Card {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("为什么推荐")
                                .font(.headline)
                                .foregroundStyle(SmartPawStyle.brown)
                            Text("尺寸和收纳方式可按你的实际空间调整，不需要一次购置大量用品。")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Button("标记为已有工具") { dismiss() }
                        .buttonStyle(PrimaryButtonStyle())
                }
                .padding(16)
            }
            .background(SmartPawStyle.canvas.ignoresSafeArea())
            .navigationTitle("购买推荐")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

private struct ARGuidePreview: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let plan: StoragePlan

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                SpacePhotoPreview(space: viewModel.selectedSpace, progress: plan.progress)
                ForEach(visibleSteps) { step in
                    let hint = step.arHint
                    if let mask = step.arMask, mask.hasRaster {
                        ARMaskOverlay(
                            mask: mask,
                            color: (step.status == .active ? SmartPawStyle.orange : SmartPawStyle.mint).opacity(0.34)
                        )
                    }
                    if step.status == .active, step.arMask?.hasRaster == true {
                        Text("当前")
                            .font(.caption2.weight(.black))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(SmartPawStyle.orange, in: Capsule())
                            .offset(x: proxy.size.width * hint.x - 24, y: proxy.size.height * hint.y - 22)
                    }
                }
            }
        }
        .clipShape(SmartPawStyle.cardShape)
    }

    private var visibleSteps: [StorageStep] {
        let selectedSteps = viewModel.selectedExecutionZones.isEmpty
            ? plan.steps
            : plan.steps.filter { viewModel.selectedExecutionZones.contains($0.zone) }
        if let active = selectedSteps.first(where: { $0.status == .active }) ?? selectedSteps.first(where: { $0.status != .done }) {
            return [active]
        }
        return []
    }
}

private struct LiveARGuideSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: AppViewModel
    @StateObject private var recognition = LiveARRecognitionModel()
    let plan: StoragePlan

    var body: some View {
        NavigationStack {
            ZStack {
                if ARWorldTrackingConfiguration.isSupported {
                    ARCameraView(recognition: recognition)
                        .ignoresSafeArea()
                    LiveAROverlay(
                        plan: plan,
                        recognizedItems: recognition.items,
                        targetItems: activeStepItems,
                        isRecognizing: recognition.isRecognizing
                    )
                } else {
                    SimulatedARGuide(plan: plan)
                        .environmentObject(viewModel)
                }

                VStack {
                    HStack(spacing: 12) {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .foregroundStyle(.white)
                                .frame(width: 38, height: 38)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .accessibilityLabel("关闭")

                        Spacer()
                        HStack(spacing: 6) {
                            Image(systemName: "arkit")
                            Text("AR 扫描")
                        }
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 13)
                        .frame(height: 38)
                        .background(.ultraThinMaterial, in: Capsule())
                        Spacer()

                        HStack(spacing: 5) {
                            Circle().fill(.red).frame(width: 7, height: 7)
                            Text("REC")
                        }
                        .font(.caption2.weight(.black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .frame(height: 32)
                        .background(.red.opacity(0.72), in: Capsule())
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    Spacer()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var activeStepItems: [DetectedItem] {
        guard let activeStep = plan.steps.first(where: { $0.status == .active }) ?? plan.steps.first(where: { $0.status != .done }) else {
            return []
        }
        let itemIDs = Set(activeStep.itemIDs)
        return viewModel.selectedSpace.detectedItems.filter { itemIDs.contains($0.id) }
    }
}

private struct SimulatedARGuide: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: AppViewModel
    let plan: StoragePlan

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { proxy in
                let image = viewModel.capturedImage
                let imageRect = aspectFillRect(imageSize: image?.size, in: proxy.size)
                ZStack {
                    Color.black
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: imageRect.width, height: imageRect.height)
                            .position(x: imageRect.midX, y: imageRect.midY)
                    } else {
                        SpacePhotoPreview(space: viewModel.selectedSpace, progress: plan.progress)
                    }

                    LiveAROverlay(
                        plan: plan,
                        recognizedItems: simulatedItems,
                        targetItems: simulatedItems,
                        isRecognizing: false,
                        contentRect: image == nil ? nil : imageRect,
                        showsProgress: false
                    )
                }
                .clipped()
            }

            HStack(spacing: 24) {
                if let image = viewModel.capturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 46, height: 62)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(simulatedItems.count) 件")
                        .font(.headline.weight(.black))
                    Text("已识别")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
                Circle()
                    .stroke(.gray.opacity(0.24), lineWidth: 5)
                    .frame(width: 64, height: 64)
                    .overlay {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(.red)
                            .frame(width: 24, height: 24)
                    }
                Spacer()

                Button { dismiss() } label: {
                    Image(systemName: "checkmark")
                        .font(.title2.weight(.black))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(SmartPawStyle.orange, in: Circle())
                }
                .accessibilityLabel("完成")
            }
            .foregroundStyle(SmartPawStyle.brown)
            .padding(.horizontal, 18)
            .frame(height: 126)
            .background(SmartPawStyle.canvas)
        }
        .background(.black)
        .ignoresSafeArea(edges: .bottom)
    }

    private var simulatedItems: [DetectedItem] {
        let stepIDs = Set(activeStep?.itemIDs ?? [])
        let fromSpace = viewModel.selectedSpace.detectedItems.filter { stepIDs.contains($0.id) && $0.arHint != nil }
        if !fromSpace.isEmpty {
            return fromSpace
        }

        guard let activeStep else { return [] }
        return [
            DetectedItem(
                name: activeStep.title,
                category: .tools,
                confidence: 1,
                suggestedZone: activeStep.zone,
                arHint: activeStep.arHint,
                arMask: activeStep.arMask
            )
        ]
    }

    private var activeStep: StorageStep? {
        plan.steps.first { $0.status == .active } ?? plan.steps.first { $0.status != .done }
    }

    private func aspectFillRect(imageSize: CGSize?, in containerSize: CGSize) -> CGRect {
        guard let imageSize, imageSize.width > 0, imageSize.height > 0 else {
            return CGRect(origin: .zero, size: containerSize)
        }
        let scale = max(containerSize.width / imageSize.width, containerSize.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(x: (containerSize.width - size.width) / 2, y: (containerSize.height - size.height) / 2, width: size.width, height: size.height)
    }
}

private final class LiveARRecognitionModel: ObservableObject {
    @Published var items: [DetectedItem] = []
    @Published var isRecognizing = false
}

private struct ARCameraView: UIViewRepresentable {
    @ObservedObject var recognition: LiveARRecognitionModel

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        arView.session.delegate = context.coordinator
        arView.session.run(configuration)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(recognition: recognition)
    }

    static func dismantleUIView(_ uiView: ARView, coordinator: ()) {
        uiView.session.pause()
    }

    final class Coordinator: NSObject, ARSessionDelegate {
        private weak var recognition: LiveARRecognitionModel?
        private var lastScanDate = Date.distantPast
        private var isProcessing = false

        init(recognition: LiveARRecognitionModel) {
            self.recognition = recognition
        }

        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            guard Date().timeIntervalSince(lastScanDate) > 1.2, !isProcessing else { return }
            lastScanDate = Date()
            isProcessing = true
            Task.detached(priority: .utility) { [weak self] in
                let items = await Self.scan(pixelBuffer: frame.capturedImage)
                await self?.finishScan(items)
            }
            Task { @MainActor [weak recognition] in
                recognition?.isRecognizing = true
            }
        }

        @MainActor
        private func finishScan(_ items: [DetectedItem]) {
            recognition?.items = items
            recognition?.isRecognizing = false
            isProcessing = false
        }

        private static func scan(pixelBuffer: CVPixelBuffer) async -> [DetectedItem] {
            guard let image = image(from: pixelBuffer) else { return [] }
            return await YOLOSegmentationScanService().scanLiveImage(image)
        }

        private static func image(from pixelBuffer: CVPixelBuffer) -> UIImage? {
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer).oriented(.right)
            let context = CIContext()
            guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
            return UIImage(cgImage: cgImage)
        }

    }
}

private struct ExecutionZoneSelector: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let plan: StoragePlan

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("选择整理区域")
                    .font(.headline.weight(.black))
                    .foregroundStyle(SmartPawStyle.brown)

                ForEach(zones, id: \.self) { zone in
                        Button {
                            viewModel.toggleExecutionZone(zone)
                        } label: {
                            HStack(spacing: 12) {
                                Text("\((zones.firstIndex(of: zone) ?? 0) + 1)")
                                    .font(.caption.weight(.black))
                                    .foregroundStyle(.white)
                                    .frame(width: 28, height: 28)
                                    .background(viewModel.selectedExecutionZones.contains(zone) ? SmartPawStyle.orange : SmartPawStyle.brown.opacity(0.38), in: Circle())
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(shortZone(zone))
                                        .font(.subheadline.weight(.bold))
                                    Text("点击后在 AR 引导中显示对应步骤")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: viewModel.selectedExecutionZones.contains(zone) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(viewModel.selectedExecutionZones.contains(zone) ? SmartPawStyle.orange : .secondary)
                            }
                            .foregroundStyle(SmartPawStyle.brown)
                            .padding(12)
                            .background(viewModel.selectedExecutionZones.contains(zone) ? SmartPawStyle.tan.opacity(0.34) : SmartPawStyle.canvas, in: SmartPawStyle.cardShape)
                        }
                        .buttonStyle(.plain)
                }

                HStack(spacing: 10) {
                    Button("全选") { viewModel.selectAllExecutionZones() }
                        .buttonStyle(SecondaryActionButtonStyle())
                    Button("清除") { viewModel.selectedExecutionZones = [] }
                        .buttonStyle(SecondaryActionButtonStyle())
                }
            }
        }
    }

    private func shortZone(_ zone: String) -> String {
        zone.components(separatedBy: "·").last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? zone
    }

    private var zones: [String] {
        Array(Set(plan.steps.map(\.zone))).sorted()
    }
}

private struct LiveAROverlay: View {
    let plan: StoragePlan
    let recognizedItems: [DetectedItem]
    var targetItems: [DetectedItem] = []
    let isRecognizing: Bool
    var contentRect: CGRect? = nil
    var showsProgress = true

    private var activeStep: StorageStep? {
        plan.steps.first { $0.status == .active } ?? plan.steps.first { $0.status != .done }
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                if let activeStep {
                    HStack(spacing: 8) {
                        Text(activeStep.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Spacer()
                        Label(activeStep.zone, systemImage: "scope")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 42)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.black.opacity(0.46), in: Capsule())
                    .padding(.horizontal, 18)
                    .padding(.top, 64)
                }

                ForEach(activeItems) { item in
                    if item.arHint != nil, let mask = item.arMask, mask.hasRaster {
                        RecognitionMask(item: item, mask: mask, contentRect: contentRect ?? CGRect(origin: .zero, size: proxy.size))
                    }
                }

                if showsProgress {
                    VStack {
                    Spacer()
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label(isRecognizing ? "实时识别中" : "实时识别", systemImage: isRecognizing ? "viewfinder.circle" : "checkmark.seal.fill")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                            Spacer()
                            Text("\(activeItems.count) 件")
                                .font(.caption.weight(.black))
                                .foregroundStyle(.white)
                        }
                        ProgressView(value: plan.progress)
                            .tint(SmartPawStyle.orange)
                    }
                    .padding(14)
                    .background(.black.opacity(0.48), in: SmartPawStyle.cardShape)
                    .padding(18)
                    }
                }
            }
        }
    }

    private var activeItems: [DetectedItem] {
        guard let activeStep else { return [] }
        let itemIDs = Set(activeStep.itemIDs)
        let exactMatches = recognizedItems.filter { itemIDs.contains($0.id) }
        if !exactMatches.isEmpty { return exactMatches }

        // Live inference creates fresh IDs every frame. Match only the current
        // step's semantic target and omit the overlay until it is seen again;
        // a mask from the captured photo has incompatible camera coordinates.
        let targetNames = Set(targetItems.map(\.name))
        let targetCategories = Set(targetItems.map(\.category))
        let semanticMatches = recognizedItems.filter {
            targetNames.contains($0.name) || targetCategories.contains($0.category)
        }
        guard !semanticMatches.isEmpty else { return [] }
        return semanticMatches
            .sorted { $0.confidence > $1.confidence }
            .prefix(max(1, targetItems.count))
            .map { $0 }
    }
}

private struct RecognitionMask: View {
    let item: DetectedItem
    let mask: ARMask
    let contentRect: CGRect

    var body: some View {
        ARMaskOverlay(mask: mask, color: maskColor.opacity(0.42))
            .frame(width: contentRect.width, height: contentRect.height)
            .position(x: contentRect.midX, y: contentRect.midY)
    }

    private var maskColor: Color {
        switch item.category {
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

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private struct CompletionPhotoCard: View {
    @Binding var selectedPhotoItem: PhotosPickerItem?
    @Binding var isShowingCamera: Bool

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(SmartPawStyle.orange)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("生成前后对比")
                            .font(.headline)
                            .foregroundStyle(SmartPawStyle.brown)
                        Text("拍摄或导入整理后的照片，灵爪会把这次成果沉淀到空间档案、成就中心和社区分享入口。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: 12) {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label("导入完成照", systemImage: "photo")
                            .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .buttonStyle(SecondaryActionButtonStyle())

                    Button {
                        isShowingCamera = true
                    } label: {
                        Label("拍完成照", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }
            }
        }
    }
}

private struct StepCard: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let step: StorageStep

    var body: some View {
        Card {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: iconName)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(iconColor)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 7) {
                    Text(step.title)
                        .font(.headline)
                        .foregroundStyle(SmartPawStyle.brown)
                    Text(step.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(step.zone)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SmartPawStyle.orange)
                }

                Spacer()

                Button {
                    viewModel.completeStep(step.id)
                } label: {
                    Image(systemName: step.status == .done ? "checkmark" : "arrow.right")
                        .frame(width: 34, height: 34)
                        .background(step.status == .done ? SmartPawStyle.mint : SmartPawStyle.orange, in: Circle())
                        .foregroundStyle(.white)
                }
                .disabled(step.status != .active)
                .accessibilityLabel("完成步骤 \(step.title)")
            }
        }
    }

    private var iconName: String {
        switch step.status {
        case .pending: "circle"
        case .active: "scope"
        case .done: "checkmark.circle.fill"
        }
    }

    private var iconColor: Color {
        switch step.status {
        case .pending: SmartPawStyle.brown.opacity(0.35)
        case .active: SmartPawStyle.orange
        case .done: SmartPawStyle.mint
        }
    }
}

struct FlowLayout: View {
    let items: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                Chip(title: item)
            }
        }
    }
}
