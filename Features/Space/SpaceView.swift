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
                                .accessibilityLabel("返回空间")
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
                Text("当前没有进行中的整理")
                    .font(FigmaFont.semibold(21))
                    .foregroundStyle(SmartPawStyle.brown)
                Text("拍摄空间并确认物品后，灵爪会在这里生成可执行步骤。")
                    .font(FigmaFont.regular(14))
                    .foregroundStyle(SmartPawStyle.brown.opacity(0.6))
                    .multilineTextAlignment(.center)
                Button("返回空间", action: onBack)
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
                        Text("成果展示")
                        Spacer()
                        Button("查看全部", action: onOpenDetail)
                    }
                    .font(FigmaFont.medium(16))
                    .foregroundStyle(SmartPawStyle.brown)

                    HStack(spacing: 10) {
                        Button(action: onOpenDetail) {
                            SpaceOverviewResultCard(
                                title: "书桌区域",
                                subtitle: "45 items · 92%",
                                assetName: completionAssetName,
                                progress: 0.92,
                                label: "完成"
                            )
                        }
                        .buttonStyle(.plain)

                        Button(action: onOpenDetail) {
                            SpaceOverviewResultCard(
                                title: "厨房储藏区",
                                subtitle: "36 items · 100%",
                                assetName: "FigmaProfilePlanCabinet",
                                progress: 1,
                                label: "完成"
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Text("进行中")
                        .font(FigmaFont.medium(16))
                        .foregroundStyle(SmartPawStyle.brown)
                        .padding(.top, 2)

                    VStack(spacing: 10) {
                        Button(action: onOpenExecution) {
                            SpaceOverviewProgressRow(
                                title: "卫生间",
                                detail: "",
                                progress: 0.35,
                                assetName: "BathroomProgress"
                            )
                        }
                        .buttonStyle(.plain)

                        Button(action: onOpenExecution) {
                            SpaceOverviewProgressRow(
                                title: "客厅",
                                detail: "",
                                progress: 0.60,
                                assetName: "FigmaProfilePlanLiving"
                            )
                        }
                        .buttonStyle(.plain)
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
        guard let plan = viewModel.activePlan else { return "暂无进行中的整理" }
        let regionCount = max(1, plan.steps.count)
        let completedCount = plan.steps.filter { $0.status == .done }.count
        return "\(completedCount) / \(regionCount) 个区域已整理"
    }

    private var activePlanTitle: String {
        viewModel.activePlan == nil ? "暂无进行中的整理" : "进行中的整理"
    }

    private var completionSubtitle: String {
        guard viewModel.selectedSpace.hasVerifiedComparison else {
            return "完成后拍摄生成真实对比"
        }
        return isDesignSample
            ? "已完成 · 45件物品"
            : "已完成 · \(viewModel.selectedSpace.detectedItems.count)件物品"
    }

    private var completionAssetName: String? {
        viewModel.selectedSpace.hasVerifiedComparison
            ? viewModel.selectedSpace.afterAssetName
            : viewModel.selectedSpace.beforeAssetName
    }

    private var isDesignSample: Bool {
        viewModel.selectedSpace.name == "宿舍桌面"
    }
}

private struct SpaceOverviewHeader: View {
    var body: some View {
        HStack(spacing: 8) {
            BrandBadge(size: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text("灵爪 · Smart Paw")
                    .font(FigmaFont.medium(11))
                    .foregroundStyle(SmartPawStyle.brown)
                Text("我的收纳空间")
                    .font(FigmaFont.semibold(16))
                    .foregroundStyle(SmartPawStyle.brown.opacity(0.86))
            }
            Spacer(minLength: 0)
            Image(systemName: "bell.badge")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(SmartPawStyle.orange)
                .frame(width: 30, height: 30)
                .background(.white, in: Circle())
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
                    Text("已完成")
                        .font(FigmaFont.regular(10))
                }
                .foregroundStyle(SmartPawStyle.brown)
            }
            .frame(width: 92, height: 92)

            VStack(alignment: .leading, spacing: 7) {
                Text("收纳进度")
                    .font(FigmaFont.semibold(15))
                    .foregroundStyle(SmartPawStyle.brown)
                HStack(spacing: 5) {
                    Text("本周")
                        .font(FigmaFont.regular(10))
                        .foregroundStyle(SmartPawStyle.brown.opacity(0.55))
                    Text("继续前进!")
                        .font(FigmaFont.semibold(13))
                        .foregroundStyle(SmartPawStyle.brown)
                }
                HStack(spacing: 6) {
                    SpaceOverviewTag(text: "12个区域", color: SmartPawStyle.tan)
                    SpaceOverviewTag(text: "+5完成", color: SmartPawStyle.blue.opacity(0.76))
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
        return max(min(total / Double(spaces.count), 1), 0.65)
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
                Text("凌乱\n有解法")
                    .font(FigmaFont.bold(38))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Image("FigmaCompletion")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 190, height: 190)
                    .clipShape(Circle())
                Spacer()
                Text("灵爪收纳")
                    .font(FigmaFont.bold(15))
                    .foregroundStyle(.white)
                    .padding(.bottom, 42)
            }
            .padding(.horizontal, 28)

            VStack {
                HStack {
                    Spacer()
                    Button("跳过") { onContinue() }
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

    private let designCompletedItems = [
        FigmaCompletedItem(title: "书本", detail: "已归位", glyph: "book.closed.fill", tint: SmartPawStyle.orange),
        FigmaCompletedItem(title: "充电设备", detail: "已收纳", glyph: "powerplug.fill", tint: SmartPawStyle.blue),
        FigmaCompletedItem(title: "文具", detail: "已分类", glyph: "pencil.and.outline", tint: SmartPawStyle.mint),
        FigmaCompletedItem(title: "小物件", detail: "已收纳", glyph: "shippingbox.fill", tint: SmartPawStyle.tan),
        FigmaCompletedItem(title: "纸张", detail: "已归档", glyph: "doc.text.fill", tint: SmartPawStyle.orange.opacity(0.74)),
        FigmaCompletedItem(title: "展示物", detail: "已摆放", glyph: "sparkles", tint: SmartPawStyle.blue.opacity(0.78))
    ]

    private let tips = [
        "常用物品放在第一伸手区，减少桌面回流。",
        "每周清空一次临时收纳盒，避免再次堆积。",
        "睡前用两分钟复位，让明天从整洁开始。"
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

                    Text("书桌区域")
                        .font(FigmaFont.semibold(22))
                        .foregroundStyle(SmartPawStyle.brown)

                    HStack(spacing: 8) {
                        FigmaComparisonStat(value: itemCountText, label: "物品")
                        FigmaComparisonStat(value: durationText, label: "时长")
                        FigmaComparisonStat(value: scoreText, label: "得分")
                    }

                    Text("前后对比")
                        .font(FigmaFont.semibold(14))
                        .foregroundStyle(SmartPawStyle.brown)
                        .padding(.top, 2)

                    FigmaBeforeAfterPhoto(space: viewModel.selectedSpace)
                        .frame(height: 138)

                    HStack {
                        Text("组织项目 · \(itemCountText)")
                            .font(FigmaFont.semibold(14))
                        Spacer()
                        Button("查看全部") {
                            viewModel.showMessage("已显示本次整理的全部物品。")
                        }
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
                        Text("存储小贴士")
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
                        Label("继续保持这个空间", systemImage: "sparkles")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(.horizontal, 15)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
        }
    }

    private var latestCompletedPlan: StoragePlan? {
        viewModel.selectedSpace.completedPlans.first
    }

    private var completionDate: String {
        if isDesignSample { return "2026年5月15日" }
        return latestCompletedPlan?.completedAt?.formatted(.dateTime.year().month().day()) ?? "待完成"
    }

    private var completionStatus: String {
        viewModel.selectedSpace.hasVerifiedComparison
            ? "已完成 · \(completionDate)"
            : "整理完成 · 待拍完成照"
    }

    private var isDesignSample: Bool {
        viewModel.selectedSpace.name == "宿舍桌面"
    }

    private var itemCountText: String {
        isDesignSample ? "45" : "\(viewModel.selectedSpace.detectedItems.count)"
    }

    private var durationText: String {
        isDesignSample ? "33 min" : (latestCompletedPlan?.timeBudget.title ?? "待完成")
    }

    private var scoreText: String {
        isDesignSample ? "+45" : "+\(viewModel.selectedSpace.detectedItems.count)"
    }

    private var displayedItems: [FigmaCompletedItem] {
        if isDesignSample { return designCompletedItems }
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
            .accessibilityLabel("返回空间")

            Spacer()

            Button(action: onFavorite) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isFavorite ? SmartPawStyle.orange : SmartPawStyle.brown)
                    .frame(width: 32, height: 32)
                    .background(.white, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isFavorite ? "取消收藏" : "收藏成果")

            Button(action: onShare) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SmartPawStyle.brown)
                    .frame(width: 32, height: 32)
                    .background(.white, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("分享成果")
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
                            Text("前后")
                                .font(FigmaFont.medium(9))
                        }
                        .foregroundStyle(SmartPawStyle.brown)
                        .frame(width: 42, height: 42)
                        .background(.white, in: Circle())
                        .shadow(color: .black.opacity(0.12), radius: 5, y: 2)

                        HStack {
                            FigmaPhotoBadge(title: "整理前")
                            Spacer()
                            FigmaPhotoBadge(title: "整理后")
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
                            Text("完成后拍摄同空间照片\n即可生成真实对比")
                                .font(FigmaFont.medium(11))
                                .multilineTextAlignment(.center)
                        }
                        .foregroundStyle(.white)
                        .padding(14)
                        .background(.black.opacity(0.48), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .overlay(alignment: .topLeading) {
                        FigmaPhotoBadge(title: "整理前")
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
        .accessibilityLabel(space.hasVerifiedComparison ? "书桌整理前后对比" : "待拍完成照的书桌整理记录")
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
                        .accessibilityLabel("返回空间")
                        Spacer()
                        Text("进行中")
                            .font(FigmaFont.medium(11))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 11)
                            .frame(height: 24)
                            .background(SmartPawStyle.blue, in: Capsule())
                    }

                    StorageImageView(url: nil, assetName: "BathroomProgress", fallbackProgress: 0)
                        .frame(height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(alignment: .bottomLeading) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("卫生间整理")
                                    .font(FigmaFont.semibold(18))
                                Text("从台面开始，逐区恢复使用秩序")
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
                            FigmaProgressMetric(icon: "clock", title: "预计时间", value: remainingTime)
                            FigmaProgressMetric(icon: "checkmark.circle", title: "区域", value: "\(completedRegionCount) / \(totalRegionCount)")
                            FigmaProgressMetric(icon: "flame", title: "连续记录", value: "4天")
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                    HStack {
                        Text("总体进度")
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
                        Text("区域")
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

                    Text("最近活动")
                        .font(FigmaFont.semibold(19))
                        .foregroundStyle(SmartPawStyle.brown)
                        .padding(.top, 5)

                    VStack(spacing: 8) {
                        ForEach(recentActivities, id: \.self) { activity in
                            FigmaRecentActivity(text: activity, time: "刚刚")
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
        viewModel.activePlan?.progress ?? 0.35
    }

    private var completedRegionCount: Int {
        viewModel.activePlan?.steps.filter { $0.status == .done }.count ?? 2
    }

    private var totalRegionCount: Int {
        max(1, viewModel.activePlan?.steps.count ?? 5)
    }

    private var remainingTime: String {
        guard let plan = viewModel.activePlan else { return "剩余 12分钟" }
        return "剩余 \(plan.timeBudget.title)"
    }

    private var steps: [FigmaProgressStep] {
        guard let plan = viewModel.activePlan else {
            let definitions = [("台面", "3任务"), ("镜柜", "5任务"), ("浴室置物架", "4任务"), ("水槽下储存", "6任务"), ("毛巾架", "2任务")]
            return definitions.enumerated().map { index, definition in
                let state: FigmaProgressStep.State = index < completedRegionCount ? .done : (index == completedRegionCount ? .current : .upcoming)
                return FigmaProgressStep(title: definition.0, detail: definition.1, state: state)
            }
        }

        return plan.steps.map { step in
            let state: FigmaProgressStep.State
            switch step.status {
            case .done: state = .done
            case .active: state = .current
            case .pending: state = .upcoming
            }
            return FigmaProgressStep(
                title: step.zone,
                detail: "\(max(1, step.itemIDs.count)) 项物品",
                state: state
            )
        }
    }

    private var recentActivities: [String] {
        let completed = viewModel.activePlan?.steps
            .filter { $0.status == .done }
            .reversed()
            .prefix(3)
            .map { "已完成：\($0.title)" } ?? []
        return completed.isEmpty ? ["已擦拭台面并重新摆放化妆品", "护肤品已归入镜柜第一层", "已清理 3 件过期物品"] : Array(completed)
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
                        Button("立即开始", action: onStart)
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
                Text(progress >= 1 ? "已完成空间" : "待整理空间")
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
                    .accessibilityLabel("真实收纳照片")
            } else if let assetName, let image = UIImage(named: assetName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .clipShape(SmartPawStyle.cardShape)
                    .accessibilityLabel("真实收纳照片")
            } else {
                DemoRoomPreview(progress: fallbackProgress)
            }
        }
    }
}
