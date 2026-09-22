import SwiftUI
import UIKit

struct SpaceView: View {
    private let initialStage: SpaceFlowStage
    @Binding private var showsBottomNavigation: Bool

    init(showsBottomNavigation: Binding<Bool> = .constant(true)) {
        _showsBottomNavigation = showsBottomNavigation
        if CommandLine.arguments.contains("-SmartPawShowSpaceDetail") {
            initialStage = .detail
        } else if CommandLine.arguments.contains("-SmartPawShowSpaceExecution") {
            initialStage = .execution
        } else {
            initialStage = .home
        }
    }

    var body: some View {
        SpaceFlowView(
            initialStage: initialStage,
            showsBottomNavigation: $showsBottomNavigation
        )
    }
}

private enum SpaceFlowStage {
    case cover, home, detail, execution, activeExecution
}

private enum SpaceExecutionOrigin {
    case home, detail
}

private struct SpaceFlowView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var stage: SpaceFlowStage
    @Binding private var showsBottomNavigation: Bool
    @State private var executionOrigin: SpaceExecutionOrigin = .home

    init(initialStage: SpaceFlowStage, showsBottomNavigation: Binding<Bool>) {
        _stage = State(initialValue: initialStage)
        _showsBottomNavigation = showsBottomNavigation
    }

    var body: some View {
        Group {
            switch stage {
            case .cover:
                SpaceCoverView {
                    withAnimation(.easeInOut(duration: 0.28)) { stage = .home }
                }
            case .home:
                FigmaSpaceHomeView(
                    onOpenDetail: { withAnimation(.easeInOut(duration: 0.28)) { stage = .detail } },
                    onOpenExecution: {
                        executionOrigin = .home
                        withAnimation(.easeInOut(duration: 0.28)) { stage = .execution }
                    }
                )
            case .detail:
                SpaceRegionDetailView(
                    onBack: { withAnimation(.easeInOut(duration: 0.28)) { stage = .home } },
                    onStart: {
                        executionOrigin = .detail
                        withAnimation(.easeInOut(duration: 0.28)) { stage = .execution }
                    }
                )
            case .execution:
                if viewModel.activePlan != nil {
                    FigmaSpaceProgressView(
                        onBack: {
                            withAnimation(.easeInOut(duration: 0.28)) {
                                stage = executionOrigin == .detail ? .detail : .home
                            }
                        },
                        onStart: {
                            withAnimation(.easeInOut(duration: 0.28)) { stage = .activeExecution }
                        }
                    )
                } else {
                    FigmaExecutionEmptyState {
                        withAnimation(.easeInOut(duration: 0.28)) { stage = .home }
                    }
                }
            case .activeExecution:
                if let plan = viewModel.activePlan {
                    NavigationStack {
                        ExecutionView(plan: plan) {
                            withAnimation(.easeInOut(duration: 0.28)) { stage = .home }
                        }
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.28)) {
                                        stage = executionOrigin == .detail ? .detail : .home
                                    }
                                } label: {
                                    Image(systemName: "chevron.left")
                                }
                                .accessibilityLabel("Back to spaces")
                            }
                        }
                    }
                } else {
                    FigmaExecutionEmptyState {
                        withAnimation(.easeInOut(duration: 0.28)) { stage = .home }
                    }
                }
            }
        }
        .environmentObject(viewModel)
        .onAppear { showsBottomNavigation = stage == .home }
        .onChange(of: stage) { _, newStage in
            showsBottomNavigation = newStage == .home
        }
    }
}

private struct FigmaExecutionEmptyState: View {
    let onBack: () -> Void

    var body: some View {
        ZStack {
            SmartPawStyle.canvas.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(SmartPawStyle.mint)
                Text("No active storage plan")
                    .font(FigmaFont.semibold(21))
                    .foregroundStyle(SmartPawStyle.brown)
                Text("Capture a space and confirm its items to generate executable steps here.")
                    .font(FigmaFont.regular(14))
                    .foregroundStyle(SmartPawStyle.brown.opacity(0.6))
                    .multilineTextAlignment(.center)
                Button("Back to spaces", action: onBack)
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 4)
            }
            .padding(28)
        }
    }
}

private struct FigmaSpaceHomeView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let onOpenDetail: () -> Void
    let onOpenExecution: () -> Void

    var body: some View {
        ZStack {
            SmartPawStyle.canvas.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    SpaceOverviewHeader()
                    SpaceOverviewProgressCard()

                    HStack {
                        Text("Results")
                        Spacer()
                        Button("View all", action: onOpenDetail)
                    }
                    .font(FigmaFont.medium(16))
                    .foregroundStyle(SmartPawStyle.brown)

                    HStack(spacing: 10) {
                        Button(action: onOpenDetail) {
                            SpaceOverviewResultCard(
                                title: viewModel.selectedSpace.name,
                                subtitle: viewModel.language == .english
                                    ? "\(viewModel.selectedSpace.detectedItems.count) items · \(completionProgressText)"
                                    : "\(viewModel.selectedSpace.detectedItems.count) 件物品 · \(completionProgressText)",
                                assetName: completionAssetName,
                                progress: completionProgress,
                                label: viewModel.selectedSpace.hasVerifiedComparison ? (viewModel.language == .english ? "Complete" : "已完成") : (viewModel.language == .english ? "Needs sorting" : "待整理")
                            )
                        }
                        .buttonStyle(.plain)

                        if let anotherSpace = viewModel.spaces.first(where: { $0.id != viewModel.selectedSpace.id }) {
                            Button {
                                viewModel.selectSpace(anotherSpace.id)
                                onOpenDetail()
                            } label: {
                                SpaceOverviewResultCard(
                                    title: anotherSpace.name,
                                    subtitle: viewModel.language == .english
                                        ? "\(anotherSpace.detectedItems.count) items · \(anotherSpaceProgress(anotherSpace))"
                                        : "\(anotherSpace.detectedItems.count) 件物品 · \(anotherSpaceProgress(anotherSpace))",
                                    assetName: anotherSpace.hasVerifiedComparison ? anotherSpace.afterAssetName : anotherSpace.beforeAssetName,
                                    progress: anotherSpace.activePlan?.progress ?? (anotherSpace.completedPlans.isEmpty ? 0 : 1),
                                    label: anotherSpace.hasVerifiedComparison ? (viewModel.language == .english ? "Complete" : "已完成") : (viewModel.language == .english ? "Needs sorting" : "待整理")
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text("In progress")
                        .font(FigmaFont.medium(16))
                        .foregroundStyle(SmartPawStyle.brown)
                        .padding(.top, 2)

                    VStack(spacing: 10) {
                        if viewModel.activePlan != nil {
                            Button(action: onOpenExecution) {
                                SpaceOverviewProgressRow(
                                    title: viewModel.selectedSpace.name,
                                    detail: activePlanDetail,
                                    progress: activePlanProgress,
                                    assetName: viewModel.selectedSpace.beforeAssetName ?? AppSampleAssets.messyDesk
                                )
                            }
                            .buttonStyle(.plain)
                        } else {
                            Text(viewModel.language == .english
                                 ? "No active plan. Capture a space and confirm its items to generate steps."
                                 : "暂无进行中的方案。拍摄空间并确认物品后即可生成步骤。")
                                .font(FigmaFont.regular(12))
                                .foregroundStyle(SmartPawStyle.brown.opacity(0.56))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 116)
            }
        }
    }

    private var activePlanProgress: Double {
        viewModel.activePlan?.progress ?? 0
    }

    private var activePlanDetail: String {
        guard let plan = viewModel.activePlan else { return "No active plan" }
        let regionCount = max(1, plan.steps.count)
        let completedCount = plan.steps.filter { $0.status == .done }.count
        return "\(completedCount) / \(regionCount) zones organized"
    }

    private var activePlanTitle: String {
        viewModel.activePlan == nil ? "No active plan" : "In progress"
    }

    private var completionSubtitle: String {
        guard viewModel.selectedSpace.hasVerifiedComparison else {
            return viewModel.language == .english ? "Capture the finished space for a real comparison" : "拍摄整理完成的空间，生成真实对比"
        }
        return viewModel.language == .english ? "Complete · \(viewModel.selectedSpace.detectedItems.count) items" : "已完成 · \(viewModel.selectedSpace.detectedItems.count) 件物品"
    }

    private var completionAssetName: String? {
        viewModel.selectedSpace.hasVerifiedComparison
            ? viewModel.selectedSpace.afterAssetName
            : viewModel.selectedSpace.beforeAssetName
    }

    private var completionProgress: Double {
        if let plan = viewModel.selectedSpace.activePlan { return plan.progress }
        return viewModel.selectedSpace.completedPlans.isEmpty ? 0 : 1
    }

    private var completionProgressText: String {
        "\(Int((completionProgress * 100).rounded()))%"
    }

    private func anotherSpaceProgress(_ space: StorageSpace) -> String {
        guard let plan = space.activePlan else {
            return space.completedPlans.isEmpty ? (viewModel.language == .english ? "Needs sorting" : "待整理") : "100%"
        }
        return "\(Int((plan.progress * 100).rounded()))%"
    }

}

private struct SpaceOverviewHeader: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        HStack(spacing: 8) {
            BrandBadge(size: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text("Smart Paw")
                    .font(FigmaFont.medium(11))
                    .foregroundStyle(SmartPawStyle.brown)
                Text("My storage spaces")
                    .font(FigmaFont.semibold(16))
                    .foregroundStyle(SmartPawStyle.brown.opacity(0.86))
            }
            Spacer(minLength: 0)
            Menu {
                ForEach(viewModel.spaces) { space in
                    Button {
                        viewModel.selectSpace(space.id)
                    } label: {
                        Label(space.name, systemImage: space.id == viewModel.selectedSpaceID ? "checkmark" : "square")
                    }
                }
            } label: {
                Image(systemName: "bell.badge")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(SmartPawStyle.orange)
                    .frame(width: 30, height: 30)
                    .background(.white, in: Circle())
            }
            .accessibilityLabel("Choose storage space")
        }
    }
}

private struct SpaceOverviewProgressCard: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(SmartPawStyle.softPanel, lineWidth: 8)
                Circle()
                    .trim(from: 0, to: overallProgress)
                    .stroke(SmartPawStyle.orange, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 1) {
                    Text("\(Int((overallProgress * 100).rounded()))%")
                        .font(FigmaFont.semibold(19))
                    Text(viewModel.language == .english ? "Complete" : "完成")
                        .font(FigmaFont.regular(10))
                }
                .foregroundStyle(SmartPawStyle.brown)
            }
            .frame(width: 92, height: 92)

            VStack(alignment: .leading, spacing: 7) {
                Text("Storage progress")
                    .font(FigmaFont.semibold(15))
                    .foregroundStyle(SmartPawStyle.brown)
                HStack(spacing: 5) {
                    Text("This week")
                        .font(FigmaFont.regular(10))
                        .foregroundStyle(SmartPawStyle.brown.opacity(0.55))
                    Text("Keep going!")
                        .font(FigmaFont.semibold(13))
                        .foregroundStyle(SmartPawStyle.brown)
                }
                HStack(spacing: 6) {
                    SpaceOverviewTag(text: viewModel.language == .english ? "\(trackedSpaceCount) spaces" : "\(trackedSpaceCount) 个空间", color: SmartPawStyle.tan)
                    SpaceOverviewTag(text: viewModel.language == .english ? "\(viewModel.completedCount) completed" : "\(viewModel.completedCount) 已完成", color: SmartPawStyle.blue.opacity(0.76))
                }
            }
            Spacer(minLength: 0)
        }
        .frame(height: 138)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 38))
                .foregroundStyle(SmartPawStyle.brown.opacity(0.12))
                .padding(13)
        }
    }

    private var overallProgress: Double {
        let spaces = viewModel.spaces
        guard !spaces.isEmpty else { return 0 }
        let total = spaces.reduce(0.0) { partial, space in
            if let plan = space.activePlan { return partial + plan.progress }
            return partial + (space.completedPlans.isEmpty ? 0 : 1)
        }
        return min(max(total / Double(spaces.count), 0), 1)
    }

    private var trackedSpaceCount: Int {
        viewModel.spaces.filter { $0.activePlan != nil || !$0.completedPlans.isEmpty }.count
    }

    private var earnedPoints: Int {
        let completedSteps = viewModel.spaces.reduce(0) { partial, space in
            let activeDone = space.activePlan?.steps.filter { $0.status == .done }.count ?? 0
            let completedDone = space.completedPlans.reduce(0) { $0 + $1.steps.filter { $0.status == .done }.count }
            return partial + activeDone + completedDone
        }
        return completedSteps * 15
    }
}

private struct SpaceOverviewTag: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(FigmaFont.medium(10))
            .foregroundStyle(SmartPawStyle.brown.opacity(0.76))
            .padding(.horizontal, 8)
                .frame(height: 20)
            .background(color, in: Capsule())
    }
}

private struct SpaceOverviewResultCard: View {
    let title: String
    let subtitle: String
    let assetName: String?
    let progress: Double
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            StorageImageView(url: nil, assetName: assetName, fallbackProgress: progress)
                .frame(height: 106)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(alignment: .topLeading) {
                    Text(label)
                        .font(FigmaFont.medium(9))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .frame(height: 21)
                        .background(SmartPawStyle.brown.opacity(0.65), in: Capsule())
                        .padding(6)
                }
            Text(title)
                .font(FigmaFont.semibold(13))
                .foregroundStyle(SmartPawStyle.brown)
            Text(subtitle)
                .font(FigmaFont.regular(10))
                .foregroundStyle(SmartPawStyle.brown.opacity(0.58))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct SpaceOverviewProgressRow: View {
    let title: String
    let detail: String
    let progress: Double
    let assetName: String

    var body: some View {
        HStack(spacing: 11) {
            StorageImageView(url: nil, assetName: assetName, fallbackProgress: 0)
            .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title)
                        .font(FigmaFont.semibold(14))
                    Spacer()
                    Text("\(Int((progress * 100).rounded()))%")
                        .font(FigmaFont.semibold(13))
                        .foregroundStyle(SmartPawStyle.orange)
                }
                if !detail.isEmpty {
                    Text(detail)
                        .font(FigmaFont.regular(11))
                        .foregroundStyle(SmartPawStyle.brown.opacity(0.58))
                }
                GeometryReader { proxy in
                    Capsule()
                        .fill(SmartPawStyle.softPanel)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(SmartPawStyle.orange)
                                .frame(width: proxy.size.width * progress)
                        }
                }
                .frame(height: 5)
            }
        }
        .foregroundStyle(SmartPawStyle.brown)
        .frame(height: 74)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct SpaceCoverView: View {
    let onContinue: () -> Void
    @State private var didAdvance = false

    var body: some View {
        ZStack {
            SmartPawStyle.orange.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                Text("Clutter\nhas a solution")
                    .font(FigmaFont.bold(38))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Image("FigmaCompletion")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 190, height: 190)
                    .clipShape(Circle())
                Spacer()
                Text("Smart Paw Storage")
                    .font(FigmaFont.bold(15))
                    .foregroundStyle(.white)
                    .padding(.bottom, 42)
            }
            .padding(.horizontal, 28)

            VStack {
                HStack {
                    Spacer()
                    Button("Skip") { onContinue() }
                        .font(FigmaFont.semibold(12))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .background(.white.opacity(0.16), in: Capsule())
                }
                Spacer()
            }
            .padding(.top, 52)
            .padding(.horizontal, 18)
        }
        .task {
            guard !didAdvance else { return }
            didAdvance = true
            try? await Task.sleep(for: .seconds(1.1))
            if !Task.isCancelled { onContinue() }
        }
    }
}

private struct SpaceRegionDetailView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let onBack: () -> Void
    let onStart: () -> Void
    @State private var isFavorite = false
    @State private var isShowingItems = false

    private let tips = [
        "Keep frequent items within reach to reduce desk clutter.",
        "Empty the temporary box weekly to prevent buildup.",
        "Reset for two minutes before bed so tomorrow starts tidy."
    ]

    var body: some View {
        ZStack {
            SmartPawStyle.canvas.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    FigmaCompletedHeader(
                        isFavorite: isFavorite,
                        onBack: onBack,
                        onFavorite: { isFavorite.toggle() },
                        onShare: { viewModel.shareLatestCompletion() }
                    )

                    Text(completionStatus)
                        .font(FigmaFont.medium(10))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 11)
                        .frame(height: 23)
                        .background(SmartPawStyle.orange, in: Capsule())

                    Text(viewModel.selectedSpace.name)
                        .font(FigmaFont.semibold(22))
                        .foregroundStyle(SmartPawStyle.brown)

                    HStack(spacing: 8) {
                        FigmaComparisonStat(value: itemCountText, label: "Items")
                        FigmaComparisonStat(value: durationText, label: "Duration")
                        FigmaComparisonStat(value: scoreText, label: "Progress")
                    }

                    Text("Before & After")
                        .font(FigmaFont.semibold(14))
                        .foregroundStyle(SmartPawStyle.brown)
                        .padding(.top, 2)

                    FigmaBeforeAfterPhoto(space: viewModel.selectedSpace)
                        .frame(height: 138)

                    HStack {
                        Text("Organized items · \(itemCountText)")
                            .font(FigmaFont.semibold(14))
                        Spacer()
                        Button("View all") { isShowingItems = true }
                        .font(FigmaFont.medium(11))
                        .foregroundStyle(SmartPawStyle.orange)
                    }
                    .foregroundStyle(SmartPawStyle.brown)
                    .padding(.top, 1)

                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                        spacing: 8
                    ) {
                        ForEach(displayedItems) { item in
                            FigmaCompletedItemCard(item: item)
                        }
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(SmartPawStyle.orange)
                        Text("Storage tips")
                            .font(FigmaFont.semibold(14))
                            .foregroundStyle(SmartPawStyle.brown)
                    }
                    .padding(.top, 2)

                    VStack(spacing: 8) {
                        ForEach(Array(tips.enumerated()), id: \.offset) { index, tip in
                            FigmaStorageTip(index: index + 1, text: tip)
                        }
                    }

                    Button(action: onStart) {
                        Label("Keep this space tidy", systemImage: "sparkles")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(.horizontal, 15)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
        }
        .sheet(isPresented: $isShowingItems) {
            SpaceItemsSheet(space: viewModel.selectedSpace)
        }
    }

    private var latestCompletedPlan: StoragePlan? {
        viewModel.selectedSpace.completedPlans.first
    }

    private var completionDate: String {
        return latestCompletedPlan?.completedAt?.formatted(.dateTime.year().month().day()) ?? "Not completed"
    }

    private var completionStatus: String {
        viewModel.selectedSpace.hasVerifiedComparison
            ? "Complete · \(completionDate)"
            : "Organized · Capture the finished space"
    }

    private var itemCountText: String {
        "\(viewModel.selectedSpace.detectedItems.count)"
    }

    private var durationText: String {
        latestCompletedPlan?.timeBudget.englishTitle ?? "Not completed"
    }

    private var scoreText: String {
        "\(Int(((viewModel.selectedSpace.activePlan?.progress ?? (latestCompletedPlan == nil ? 0 : 1)) * 100).rounded()))%"
    }

    private var displayedItems: [FigmaCompletedItem] {
        return viewModel.selectedSpace.detectedItems.map { item in
            FigmaCompletedItem(
                title: item.name,
                detail: item.category.rawValue,
                glyph: glyph(for: item.category),
                tint: tint(for: item.category)
            )
        }
    }

    private func glyph(for category: ItemCategory) -> String {
        switch category {
        case .books: "book.closed.fill"
        case .electronics: "desktopcomputer"
        case .stationery: "pencil.and.outline"
        case .clothes: "tshirt.fill"
        case .toys: "teddybear.fill"
        case .trash: "trash.fill"
        case .tools: "shippingbox.fill"
        }
    }

    private func tint(for category: ItemCategory) -> Color {
        switch category {
        case .books, .trash: SmartPawStyle.orange
        case .electronics, .tools: SmartPawStyle.blue
        case .stationery: SmartPawStyle.mint
        case .clothes, .toys: SmartPawStyle.tan
        }
    }

}

private struct SpaceItemsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let space: StorageSpace

    var body: some View {
        NavigationStack {
            List(space.detectedItems) { item in
                HStack(spacing: 12) {
                    Image(systemName: icon(for: item.category))
                        .foregroundStyle(SmartPawStyle.orange)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.name)
                            .font(FigmaFont.medium(14))
                        Text("\(item.englishCategory) · Suggested: \(item.englishZone)")
                            .font(FigmaFont.regular(11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(Int((item.confidence * 100).rounded()))%")
                        .font(FigmaFont.regular(10))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 3)
            }
            .navigationTitle("Organized items")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func icon(for category: ItemCategory) -> String {
        switch category {
        case .books: "book.closed.fill"
        case .electronics: "desktopcomputer"
        case .stationery: "pencil"
        case .clothes: "tshirt.fill"
        case .toys: "teddybear.fill"
        case .trash: "trash.fill"
        case .tools: "shippingbox.fill"
        }
    }
}

private struct FigmaCompletedHeader: View {
    let isFavorite: Bool
    let onBack: () -> Void
    let onFavorite: () -> Void
    let onShare: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(SmartPawStyle.brown)
                    .frame(width: 32, height: 32)
                    .background(.white, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to spaces")

            Spacer()

            Button(action: onFavorite) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isFavorite ? SmartPawStyle.orange : SmartPawStyle.brown)
                    .frame(width: 32, height: 32)
                    .background(.white, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isFavorite ? "Remove saved result" : "Save result")

            Button(action: onShare) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SmartPawStyle.brown)
                    .frame(width: 32, height: 32)
                    .background(.white, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Share result")
        }
    }
}

private struct FigmaComparisonStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(FigmaFont.semibold(13))
                .foregroundStyle(SmartPawStyle.orange)
            Text(label)
                .font(FigmaFont.regular(9))
                .foregroundStyle(SmartPawStyle.brown.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct FigmaBeforeAfterPhoto: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let space: StorageSpace

    var body: some View {
        GeometryReader { proxy in
            Group {
                if space.hasVerifiedComparison {
                    ZStack {
                        HStack(spacing: 0) {
                            StorageImageView(
                                url: viewModel.imageURL(for: space.beforeImageName),
                                assetName: space.beforeAssetName,
                                fallbackProgress: 0
                            )
                            .frame(width: proxy.size.width / 2, height: proxy.size.height)

                            StorageImageView(
                                url: viewModel.imageURL(for: space.afterImageName),
                                assetName: space.afterAssetName,
                                fallbackProgress: 1
                            )
                            .frame(width: proxy.size.width / 2, height: proxy.size.height)
                        }

                        Rectangle()
                            .fill(.white.opacity(0.9))
                            .frame(width: 2)

                        VStack(spacing: 2) {
                            Image(systemName: "arrow.left.arrow.right")
                                .font(.system(size: 10, weight: .bold))
                            Text("Before & After")
                                .font(FigmaFont.medium(9))
                        }
                        .foregroundStyle(SmartPawStyle.brown)
                        .frame(width: 42, height: 42)
                        .background(.white, in: Circle())
                        .shadow(color: .black.opacity(0.12), radius: 5, y: 2)

                        HStack {
                            FigmaPhotoBadge(title: "Before")
                            Spacer()
                            FigmaPhotoBadge(title: "After")
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    }
                } else {
                    StorageImageView(
                        url: viewModel.imageURL(for: space.beforeImageName),
                        assetName: space.beforeAssetName,
                        fallbackProgress: 0
                    )
                    .overlay {
                        VStack(spacing: 6) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Capture the same space after organizing\nto create a real comparison")
                                .font(FigmaFont.medium(11))
                                .multilineTextAlignment(.center)
                        }
                        .foregroundStyle(.white)
                        .padding(14)
                        .background(.black.opacity(0.48), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .overlay(alignment: .topLeading) {
                        FigmaPhotoBadge(title: "Before")
                            .padding(8)
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.82), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(space.hasVerifiedComparison ? "\(space.englishName) before and after comparison" : "Pending finished photo for \(space.englishName)")
    }
}

private struct FigmaPhotoBadge: View {
    let title: String

    var body: some View {
        Text(title)
            .font(FigmaFont.medium(9))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .frame(height: 21)
            .background(SmartPawStyle.brown.opacity(0.65), in: Capsule())
    }
}

private struct FigmaCompletedItem: Identifiable {
    let title: String
    let detail: String
    let glyph: String
    let tint: Color

    var id: String { title }
}

private struct FigmaCompletedItemCard: View {
    let item: FigmaCompletedItem

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: item.glyph)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(item.tint)
                .frame(width: 30, height: 30)
                .background(item.tint.opacity(0.15), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(FigmaFont.medium(11))
                    .foregroundStyle(SmartPawStyle.brown)
                    .lineLimit(1)
                Text(item.detail)
                    .font(FigmaFont.regular(9))
                    .foregroundStyle(SmartPawStyle.blue.opacity(0.96))
                    .padding(.horizontal, 6)
                    .frame(height: 16)
                    .background(SmartPawStyle.blue.opacity(0.22), in: Capsule())
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct FigmaStorageTip: View {
    let index: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Text("\(index)")
                .font(FigmaFont.semibold(10))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(SmartPawStyle.orange, in: Circle())
            Text(text)
                .font(FigmaFont.regular(11))
                .foregroundStyle(SmartPawStyle.brown.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct FigmaSpaceProgressView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let onBack: () -> Void
    let onStart: () -> Void

    var body: some View {
        ZStack {
            SmartPawStyle.canvas.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Button(action: onBack) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(SmartPawStyle.brown)
                                .frame(width: 32, height: 32)
                                .background(.white, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Back to spaces")
                        Spacer()
                        Text("In progress")
                            .font(FigmaFont.medium(11))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 11)
                            .frame(height: 24)
                            .background(SmartPawStyle.blue, in: Capsule())
                    }

                    StorageImageView(
                        url: nil,
                        assetName: viewModel.selectedSpace.hasVerifiedComparison
                            ? viewModel.selectedSpace.afterAssetName
                            : viewModel.selectedSpace.beforeAssetName,
                        fallbackProgress: progress
                    )
                        .frame(height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(alignment: .bottomLeading) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(viewModel.selectedSpace.name)
                                    .font(FigmaFont.semibold(18))
                                Text(viewModel.selectedSpace.subtitle)
                                    .font(FigmaFont.regular(11))
                            }
                            .foregroundStyle(.white)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.black.opacity(0.36))
                        }

                    HStack(spacing: 14) {
                        ZStack {
                            Circle().stroke(SmartPawStyle.softPanel, lineWidth: 11)
                            Circle()
                                .trim(from: 0, to: progress)
                                .stroke(SmartPawStyle.orange, style: StrokeStyle(lineWidth: 11, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            VStack(spacing: 1) {
                                Text("\(Int((progress * 100).rounded()))%")
                                    .font(FigmaFont.semibold(23))
                                Text("Complete")
                                    .font(FigmaFont.regular(10))
                            }
                            .foregroundStyle(SmartPawStyle.brown)
                        }
                        .frame(width: 122, height: 122)

                        VStack(alignment: .leading, spacing: 12) {
                            FigmaProgressMetric(icon: "clock", title: "Estimated time", value: remainingTime)
                            FigmaProgressMetric(icon: "checkmark.circle", title: "Zones", value: "\(completedRegionCount) / \(totalRegionCount)")
                            FigmaProgressMetric(icon: "checkmark.seal", title: "Past completions", value: "\(viewModel.selectedSpace.completedPlans.count)")
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                    HStack {
                        Text("Overall progress")
                        Spacer()
                        Text("\(Int((progress * 100).rounded()))%").foregroundStyle(SmartPawStyle.orange)
                    }
                    .font(FigmaFont.medium(15))
                    .foregroundStyle(SmartPawStyle.brown)

                    GeometryReader { proxy in
                        Capsule()
                            .fill(.white)
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(SmartPawStyle.orange)
                                    .frame(width: proxy.size.width * progress)
                            }
                    }
                    .frame(height: 12)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Zones")
                            .font(FigmaFont.semibold(19))
                        Text("Step-by-step breakdown")
                            .font(FigmaFont.regular(12))
                            .foregroundStyle(SmartPawStyle.brown.opacity(0.45))
                    }
                    .foregroundStyle(SmartPawStyle.brown)
                    .padding(.top, 4)

                    VStack(spacing: 0) {
                        ForEach(steps) { step in
                            FigmaProgressTimelineRow(step: step, onStart: onStart)
                        }
                    }

                    Text("Recent activity")
                        .font(FigmaFont.semibold(19))
                        .foregroundStyle(SmartPawStyle.brown)
                        .padding(.top, 5)

                    VStack(spacing: 8) {
                        ForEach(recentActivities, id: \.self) { activity in
                            FigmaRecentActivity(text: EnglishDisplay.text(activity), time: "Just now")
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 34)
            }
        }
    }

    private var progress: Double {
        viewModel.activePlan?.progress ?? 0
    }

    private var completedRegionCount: Int {
        viewModel.activePlan?.steps.filter { $0.status == .done }.count ?? 0
    }

    private var totalRegionCount: Int {
        max(1, viewModel.activePlan?.steps.count ?? 0)
    }

    private var remainingTime: String {
        guard let plan = viewModel.activePlan else { return "No plan" }
        return "Budget \(plan.timeBudget.englishTitle)"
    }

    private var steps: [FigmaProgressStep] {
        guard let plan = viewModel.activePlan else { return [] }

        return plan.steps.map { step in
            let state: FigmaProgressStep.State
            switch step.status {
            case .done: state = .done
            case .active: state = .current
            case .pending: state = .upcoming
            }
            return FigmaProgressStep(
                title: step.zone,
                detail: "\(max(1, step.itemIDs.count)) items",
                state: state
            )
        }
    }

    private var recentActivities: [String] {
        let completed = viewModel.activePlan?.steps
            .filter { $0.status == .done }
            .reversed()
            .prefix(3)
            .map { "Completed: \(EnglishDisplay.text($0.title))" } ?? []
        return completed.isEmpty ? ["Waiting to start the first storage step"] : Array(completed)
    }
}

private struct FigmaProgressStep: Identifiable {
    enum State { case done, current, upcoming }
    let title: String
    let detail: String
    let state: State
    var id: String { title }
}

private struct FigmaProgressMetric: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(SmartPawStyle.orange)
                .frame(width: 18)
            Text(title)
                .font(FigmaFont.regular(11))
                .foregroundStyle(SmartPawStyle.brown.opacity(0.52))
            Spacer(minLength: 0)
            Text(value)
                .font(FigmaFont.medium(12))
                .foregroundStyle(SmartPawStyle.brown)
        }
    }
}

private struct FigmaProgressTimelineRow: View {
    let step: FigmaProgressStep
    let onStart: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Image(systemName: iconName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(step.state == .upcoming ? SmartPawStyle.orange : .white)
                    .frame(width: 40, height: 40)
                    .background(circleColor, in: Circle())
                    .overlay { Circle().stroke(SmartPawStyle.orange, lineWidth: step.state == .upcoming ? 3 : 0) }
                Rectangle()
                    .fill(SmartPawStyle.orange.opacity(step.state == .upcoming ? 0.24 : 0.85))
                    .frame(width: 3, height: 30)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.title)
                            .font(FigmaFont.semibold(15))
                        Text(step.detail)
                            .font(FigmaFont.regular(11))
                            .foregroundStyle(SmartPawStyle.brown.opacity(0.52))
                    }
                    Spacer()
                    if step.state == .current {
                        Button("Start now", action: onStart)
                            .font(FigmaFont.medium(11))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .frame(height: 28)
                            .background(SmartPawStyle.orange, in: Capsule())
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(step.state == .current ? .white : Color.clear, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .padding(.top, 1)
        }
        .foregroundStyle(SmartPawStyle.brown)
    }

    private var iconName: String {
        step.state == .done ? "checkmark" : "circle"
    }

    private var circleColor: Color {
        step.state == .upcoming ? .white : SmartPawStyle.orange
    }
}

private struct FigmaRecentActivity: View {
    let text: String
    let time: String

    var body: some View {
        HStack(spacing: 9) {
            Circle().fill(SmartPawStyle.orange).frame(width: 7, height: 7)
            Text(text)
                .font(FigmaFont.regular(12))
                .foregroundStyle(SmartPawStyle.brown)
            Spacer(minLength: 4)
            Text(time)
                .font(FigmaFont.regular(10))
                .foregroundStyle(SmartPawStyle.brown.opacity(0.45))
        }
        .padding(12)
        .background(.white, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

struct DemoRoomPreview: View {
    let progress: Double

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [SmartPawStyle.tan, SmartPawStyle.canvas],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 8) {
                Image(systemName: progress >= 1 ? "sparkles" : "shippingbox.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(SmartPawStyle.brown.opacity(0.5))
                Text(progress >= 1 ? "Completed space" : "Space to organize")
                    .font(FigmaFont.medium(11))
                    .foregroundStyle(SmartPawStyle.brown.opacity(0.58))
            }
        }
    }
}

struct SpacePhotoPreview: View {
    let space: StorageSpace
    let progress: Double

    var body: some View {
        StorageImageView(
            url: nil,
            assetName: progress >= 1 ? space.afterAssetName : space.beforeAssetName,
            fallbackProgress: progress
        )
    }
}

struct StoredImageView: View {
    let url: URL
    var fallbackProgress: Double

    var body: some View {
        StorageImageView(url: url, assetName: nil, fallbackProgress: fallbackProgress)
    }
}

struct StorageImageView: View {
    var url: URL?
    var assetName: String?
    var fallbackProgress: Double

    var body: some View {
        GeometryReader { proxy in
            if let url, let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .clipShape(SmartPawStyle.cardShape)
                    .accessibilityLabel("Real storage photo")
            } else if let assetName, let image = UIImage(named: assetName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .clipShape(SmartPawStyle.cardShape)
                    .accessibilityLabel("Real storage photo")
            } else {
                DemoRoomPreview(progress: fallbackProgress)
            }
        }
    }
}
