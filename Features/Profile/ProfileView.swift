import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var destination: ProfileDestination?

    var body: some View {
        ProfileFigmaHub(
            onPlans: { destination = .plans },
            onBadges: { destination = .badges },
            onSavedPosts: { viewModel.showMessage("已保存的帖子将在社区版本中同步显示。") }
        )
        .fullScreenCover(item: $destination) { screen in
            switch screen {
            case .plans:
                ProfileFigmaPlansView(onDismiss: { destination = nil }, onSchedule: { destination = .schedule })
                    .environmentObject(viewModel)
            case .badges:
                ProfileFigmaBadgesView(onDismiss: { destination = nil }) { badge in
                    destination = .badgeDetail(badge)
                }
            case .schedule:
                ProfileFigmaScheduleView(onDismiss: { destination = .plans })
                    .environmentObject(viewModel)
            case let .badgeDetail(badge):
                ProfileFigmaBadgeDetailView(badge: badge, onDismiss: { destination = .badges })
            }
        }
    }
}

private enum ProfileDestination: Identifiable {
    case plans
    case badges
    case schedule
    case badgeDetail(ProfileBadge)

    var id: String {
        switch self {
        case .plans: "plans"
        case .badges: "badges"
        case .schedule: "schedule"
        case let .badgeDetail(badge): "badge-\(badge.id)"
        }
    }
}

// MARK: - 1. Personal hub

private struct ProfileFigmaHub: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let onPlans: () -> Void
    let onBadges: () -> Void
    let onSavedPosts: () -> Void

    private var quickBadges: [ProfileBadge] {
        Array(ProfileBadge.from(achievements: viewModel.achievements, viewModel: viewModel).prefix(5))
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    profileHeader
                    metrics
                    badgeStrip
                    profileRows
                    supportRows
                }
                .padding(.horizontal, 22)
                .padding(.top, 28)
                .padding(.bottom, 116)
            }
        }
    }

    private var profileHeader: some View {
        VStack(spacing: 7) {
            Image("FigmaCompletion")
                .resizable()
                .scaledToFill()
                .frame(width: 62, height: 62)
                .background(SmartPawStyle.canvas, in: Circle())
                .clipShape(Circle())
            Text("Sarah Chen")
                .font(FigmaFont.medium(16))
                .foregroundStyle(SmartPawStyle.brown)
            Text("@sarah · 于2026年5月加入")
                .font(FigmaFont.regular(10))
                .foregroundStyle(SmartPawStyle.brown.opacity(0.45))
            Text("4级 · 整洁大师")
                .font(FigmaFont.medium(9))
                .foregroundStyle(SmartPawStyle.brown.opacity(0.48))
                .padding(.horizontal, 11)
                .frame(height: 21)
                .background(SmartPawStyle.canvas, in: Capsule())
        }
        .padding(.bottom, 22)
    }

    private var metrics: some View {
        HStack(spacing: 0) {
            ProfileMetric(value: "248", label: "跟踪的项目")
            ProfileMetric(value: "12", label: "空间已清理")
            ProfileMetric(value: "7", label: "获得的徽章")
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) { Rectangle().fill(SmartPawStyle.hairline).frame(height: 1) }
    }

    private var badgeStrip: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("徽章")
                    .font(FigmaFont.medium(12))
                Spacer()
                Button("查看全部", action: onBadges)
                    .font(FigmaFont.regular(10))
                    .foregroundStyle(SmartPawStyle.brown.opacity(0.48))
            }
            HStack(spacing: 9) {
                ForEach(Array(quickBadges.enumerated()), id: \.element.id) { index, badge in
                    Group {
                        if index == 0 {
                            Text("🦝")
                                .font(.system(size: 20))
                        } else {
                            ProfileBadgeGraphic(badge: badge, size: 35)
                        }
                    }
                        .frame(width: 35, height: 35)
                        .background(
                            index == 0 ? SmartPawStyle.orange : (badge.isLocked ? SmartPawStyle.canvas : badge.color.opacity(0.16)),
                            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                        )
                }
            }
        }
        .foregroundStyle(SmartPawStyle.brown)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 17)
        .overlay(alignment: .bottom) { Rectangle().fill(SmartPawStyle.hairline).frame(height: 1) }
    }

    private var profileRows: some View {
        VStack(spacing: 0) {
            ProfileListRow(icon: "calendar", title: "我的计划", subtitle: "3个待完成", action: onPlans)
            ProfileListRow(icon: "bookmark", title: "已保存的帖子", subtitle: "24", action: onSavedPosts)
            ProfileListRow(icon: "person.2", title: "关联好友", subtitle: "邀请和分享")
        }
        .padding(.top, 9)
    }

    private var supportRows: some View {
        VStack(spacing: 0) {
            ProfileListRow(icon: "questionmark.circle", title: "帮助和反馈")
            ProfileListRow(icon: "rectangle.portrait.and.arrow.right", title: "退出登录", isDestructive: true)
        }
        .padding(.top, 86)
    }
}

private struct ProfileMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(FigmaFont.medium(14))
            Text(label).font(FigmaFont.regular(9)).foregroundStyle(SmartPawStyle.brown.opacity(0.46))
        }
        .foregroundStyle(SmartPawStyle.brown)
        .frame(maxWidth: .infinity)
    }
}

private struct ProfileListRow: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var isDestructive = false
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isDestructive ? SmartPawStyle.brown.opacity(0.52) : SmartPawStyle.brown.opacity(0.58))
                    .frame(width: 42, height: 42)
                    .background(SmartPawStyle.canvas, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(FigmaFont.regular(12))
                    if let subtitle { Text(subtitle).font(FigmaFont.regular(8)).foregroundStyle(SmartPawStyle.brown.opacity(0.45)) }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(SmartPawStyle.brown.opacity(0.3))
            }
            .frame(height: 66)
            .overlay(alignment: .bottom) { Rectangle().fill(SmartPawStyle.hairline).frame(height: 1).padding(.leading, 54) }
        }
        .buttonStyle(.plain)
        .foregroundStyle(SmartPawStyle.brown)
    }
}

// MARK: - 2. Badge wall

struct ProfileFigmaBadgesView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let onDismiss: () -> Void
    let onBadge: (ProfileBadge) -> Void
    @State private var selectedFilter = BadgeFilterKind.all

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    private var allBadges: [ProfileBadge] { ProfileBadge.from(achievements: viewModel.achievements, viewModel: viewModel) }

    private var visibleBadges: [ProfileBadge] {
        switch selectedFilter {
        case .all: allBadges
        case .earned: allBadges.filter { !$0.isLocked }
        case .locked: allBadges.filter(\.isLocked)
        }
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ProfileNavigation(title: "徽章", trailing: "square.and.arrow.up", onBack: onDismiss)
                    HStack(spacing: 11) {
                        Image(systemName: "diamond.fill").font(.system(size: 22)).foregroundStyle(.white)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("你已获得").font(FigmaFont.regular(9)).foregroundStyle(.white.opacity(0.72))
                            Text("\(allBadges.filter { !$0.isLocked }.count) / \(allBadges.count)").font(FigmaFont.medium(23)).foregroundStyle(.white)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 18)
                    .frame(height: 72)
                    .background(ProfilePalette.brownGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.top, 9)

                    HStack(spacing: 8) {
                        ForEach(BadgeFilterKind.allCases) { filter in
                            BadgeFilter(title: filter.title, selected: selectedFilter == filter) {
                                selectedFilter = filter
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)

                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(visibleBadges) { badge in
                            Button { onBadge(badge) } label: { BadgeTile(badge: badge) }
                                .buttonStyle(.plain)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Rarity").font(FigmaFont.medium(10))
                        HStack(spacing: 7) {
                            RarityLabel(title: "普通", color: ProfilePalette.mutedBlue)
                            RarityLabel(title: "稀有", color: ProfilePalette.mint)
                            RarityLabel(title: "史诗", color: ProfilePalette.orange)
                            RarityLabel(title: "传奇", color: ProfilePalette.gold)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 16)
                    .padding(.bottom, 34)
                }
                .padding(.horizontal, 18)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FigmaBottomBar(selection: $viewModel.selectedTab)
        }
    }
}

struct ProfileFigmaBadgeDetailView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let badge: ProfileBadge
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            ProfileFigmaBadgesView(onDismiss: onDismiss, onBadge: { _ in })
                .disabled(true)
                .overlay(Color.black.opacity(0.36).ignoresSafeArea())
            VStack(spacing: 12) {
                HStack { Spacer(); Button(action: onDismiss) { Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundStyle(SmartPawStyle.brown.opacity(0.42)).frame(width: 24, height: 24).background(SmartPawStyle.canvas, in: Circle()) }.buttonStyle(.plain) }
                Group {
                    if badge.isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(SmartPawStyle.brown.opacity(0.38))
                    } else {
                        ProfileBadgeGraphic(badge: badge, size: 72)
                    }
                }
                .frame(width: 72, height: 72)
                .background(badge.isLocked ? SmartPawStyle.canvas : badge.color.opacity(0.14), in: Circle())
                Text(badge.isLocked ? "徽章尚未解锁" : badge.title).font(FigmaFont.medium(17)).foregroundStyle(SmartPawStyle.brown)
                Text(badge.description).font(FigmaFont.regular(10)).foregroundStyle(SmartPawStyle.brown.opacity(0.53)).multilineTextAlignment(.center)
                Text(badge.isLocked ? "完成 1 次整理计划即可获得" : "2026年4月12日获得")
                    .font(FigmaFont.regular(9))
                    .foregroundStyle(SmartPawStyle.brown.opacity(0.45))
                    .padding(.horizontal, 10).frame(height: 22).background(SmartPawStyle.canvas, in: Capsule())
                Button(badge.isLocked ? "去完成计划" : "共享徽章") {
                    if badge.isLocked { onDismiss() }
                }
                    .font(FigmaFont.medium(11)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 39)
                    .background(SmartPawStyle.orange, in: Capsule())
                    .padding(.top, 2)
            }
            .padding(18)
            .frame(width: 286)
            .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 18, y: 8)
        }
    }
}

private enum BadgeFilterKind: CaseIterable, Identifiable {
    case all
    case earned
    case locked

    var id: Self { self }

    var title: String {
        switch self {
        case .all: "全部"
        case .earned: "已获得"
        case .locked: "已锁定"
        }
    }
}

private struct BadgeFilter: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title).font(FigmaFont.regular(10)).foregroundStyle(selected ? .white : SmartPawStyle.brown.opacity(0.58))
                .padding(.horizontal, 12).frame(height: 24)
                .background(selected ? SmartPawStyle.orange : SmartPawStyle.canvas, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct BadgeTile: View {
    let badge: ProfileBadge
    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .bottomTrailing) {
                ProfileBadgeGraphic(badge: badge, size: 50)
                    .frame(width: 56, height: 56)
                    .background(badge.assetName == nil ? (badge.isLocked ? SmartPawStyle.canvas : badge.color.opacity(0.14)) : .clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                if badge.isLocked { Image(systemName: "lock.fill").font(.system(size: 7)).foregroundStyle(.white).frame(width: 16, height: 16).background(SmartPawStyle.brown.opacity(0.45), in: Circle()).offset(x: 3, y: 3) }
            }
            .frame(maxWidth: .infinity)
            Text(badge.title).font(FigmaFont.regular(9)).foregroundStyle(SmartPawStyle.brown.opacity(badge.isLocked ? 0.42 : 0.82)).lineLimit(1)
        }
    }
}

private struct ProfileBadgeGraphic: View {
    let badge: ProfileBadge
    let size: CGFloat

    var body: some View {
        Group {
            if let assetName = badge.assetName {
                if badge.id == "tidy" {
                    Image(assetName).resizable().scaledToFill().clipShape(Circle())
                } else {
                    Image(assetName).resizable().scaledToFit()
                }
            } else {
                Image(systemName: badge.symbol)
                    .font(.system(size: size * 0.42, weight: .medium))
                    .foregroundStyle(badge.isLocked ? SmartPawStyle.brown.opacity(0.32) : badge.color)
            }
        }
        .frame(width: size, height: size)
    }
}

private struct RarityLabel: View {
    let title: String
    let color: Color
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title).font(FigmaFont.regular(8)).foregroundStyle(SmartPawStyle.brown.opacity(0.55))
        }
    }
}

// MARK: - 3. Plans and 4. Calendar

struct ProfileFigmaPlansView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let onDismiss: () -> Void
    var onSchedule: () -> Void = {}
    @State private var selectedSegment = "全部"
    private let segments = ["全部", "活跃的", "已完成"]

    private var plans: [ProfilePlan] {
        viewModel.spaces.flatMap { space in
            var result: [ProfilePlan] = []
            if let plan = space.activePlan {
                result.append(ProfilePlan(id: plan.id.uuidString, imageName: "FigmaProfilePlanCloset", status: "活跃中", spaceName: space.name, title: plan.summary, progress: plan.progress, dateText: plan.timeBudget.title, isDone: false))
            }
            result += space.completedPlans.map { plan in
                ProfilePlan(id: plan.id.uuidString, imageName: "FigmaProfilePlanLiving", status: "已完成", spaceName: space.name, title: plan.summary, progress: 1, dateText: plan.completedAt?.formatted(.dateTime.month().day()) ?? "已完成", isDone: true)
            }
            return result
        }
    }

    private var visiblePlans: [ProfilePlan] {
        switch selectedSegment {
        case "活跃的": plans.filter { !$0.isDone }
        case "已完成": plans.filter(\.isDone)
        default: plans
        }
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ProfileNavigation(title: "我的计划", trailing: "plus", onBack: onDismiss)
                    HStack {
                        VStack(alignment: .leading, spacing: 3) { Text("本周").font(FigmaFont.regular(10)).foregroundStyle(.white.opacity(0.7)); Text("\(plans.filter { !$0.isDone }.count)个活动计划").font(FigmaFont.medium(17)).foregroundStyle(.white) }
                        Spacer()
                        Image(systemName: "calendar").font(.system(size: 17)).foregroundStyle(.white.opacity(0.84))
                    }
                    .padding(.horizontal, 16).frame(height: 70)
                    .background(ProfilePalette.brownGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.top, 9)
                    HStack(spacing: 7) {
                        ForEach(segments, id: \.self) { segment in
                            Button { selectedSegment = segment } label: { Text(segment).font(FigmaFont.regular(9)).foregroundStyle(selectedSegment == segment ? .white : SmartPawStyle.brown.opacity(0.55)).padding(.horizontal, 11).frame(height: 25).background(selectedSegment == segment ? SmartPawStyle.orange : SmartPawStyle.canvas, in: Capsule()) }.buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 12)
                    ForEach(visiblePlans) { plan in
                        ProfilePlanCard(plan: plan) {
                            viewModel.continueActivePlan()
                            viewModel.showMessage(plan.isDone ? "该计划已完成" : "已返回空间继续「\(plan.title)」")
                        }
                            .padding(.bottom, 9)
                    }
                    Button(action: onSchedule) { Label("查看日程", systemImage: "calendar").font(FigmaFont.medium(12)).foregroundStyle(SmartPawStyle.brown).frame(maxWidth: .infinity, minHeight: 42).background(SmartPawStyle.canvas, in: RoundedRectangle(cornerRadius: 12, style: .continuous)) }
                        .buttonStyle(.plain).padding(.top, 3).padding(.bottom, 32)
                }
                .padding(.horizontal, 18)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FigmaBottomBar(selection: $viewModel.selectedTab)
        }
    }
}

private struct ProfilePlanCard: View {
    let plan: ProfilePlan
    let onToggle: () -> Void

    private var figmaImageName: String {
        plan.imageName
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(figmaImageName).resizable().scaledToFill().frame(width: 59, height: 59).clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(plan.status).font(FigmaFont.medium(7)).foregroundStyle(plan.isDone ? .white : SmartPawStyle.orange)
                        .padding(.horizontal, 5).frame(height: 14)
                        .background(plan.isDone ? SmartPawStyle.mint : SmartPawStyle.orange.opacity(0.12), in: Capsule())
                    Text(plan.spaceName).font(FigmaFont.regular(8)).foregroundStyle(SmartPawStyle.brown.opacity(0.48))
                }
                Text(plan.title).font(FigmaFont.medium(12)).foregroundStyle(SmartPawStyle.brown).lineLimit(1)
                ProgressView(value: plan.progress).tint(plan.isDone ? SmartPawStyle.mint : SmartPawStyle.orange).frame(width: 112)
                Text(plan.dateText).font(FigmaFont.regular(8)).foregroundStyle(SmartPawStyle.brown.opacity(0.45))
            }
            Spacer()
            Button(action: onToggle) { Text(plan.isDone ? "已完成" : "继续").font(FigmaFont.medium(9)).foregroundStyle(plan.isDone ? SmartPawStyle.mint : .white).padding(.horizontal, 10).frame(height: 24).background(plan.isDone ? SmartPawStyle.mint.opacity(0.13) : SmartPawStyle.orange, in: Capsule()) }.buttonStyle(.plain)
        }
        .padding(9).background(.white, in: RoundedRectangle(cornerRadius: 11, style: .continuous)).overlay { RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(SmartPawStyle.hairline, lineWidth: 1) }
    }
}

private struct ProfilePlan: Identifiable {
    let id: String
    let imageName: String
    let status: String
    let spaceName: String
    let title: String
    let progress: Double
    let dateText: String
    let isDone: Bool

    static let figmaPlans: [ProfilePlan] = [
        .init(id: "closet", imageName: "FigmaProfilePlanCloset", status: "活跃中", spaceName: "卧室", title: "迷你衣橱整理", progress: 0.42, dateText: "立即开始", isDone: false),
        .init(id: "cabinet", imageName: "FigmaProfilePlanCabinet", status: "已排期", spaceName: "客厅", title: "5分钟柜体重置", progress: 0.66, dateText: "昨天", isDone: false),
        .init(id: "living", imageName: "FigmaProfilePlanLiving", status: "已完成", spaceName: "社区复刻", title: "周末方案回收", progress: 1, dateText: "星期日", isDone: true),
        .init(id: "living-done", imageName: "FigmaToolBox", status: "DONE", spaceName: "厨房", title: "餐具分类整理", progress: 1, dateText: "4月30日", isDone: true)
    ]
}

struct ProfileFigmaScheduleView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let onDismiss: () -> Void
    private let weekdays = ["日", "一", "二", "三", "四", "五", "六"]
    private let calendar = Calendar(identifier: .gregorian)

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ProfileNavigation(title: "日程", trailing: "plus", onBack: onDismiss, onTrailing: { viewModel.addScheduleItem(title: "新的整理计划", dueDate: Date().addingTimeInterval(86400), note: "复盘本次整理状态") })
                    HStack { VStack(alignment: .leading, spacing: 3) { Text("本月").font(FigmaFont.regular(10)).foregroundStyle(.white.opacity(0.72)); Text("\(viewModel.scheduleItems.count)项计划").font(FigmaFont.medium(17)).foregroundStyle(.white) }; Spacer(); Image(systemName: "chart.bar.fill").foregroundStyle(.white.opacity(0.84)) }
                        .padding(.horizontal, 16).frame(height: 70).background(ProfilePalette.brownGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous)).padding(.top, 9)
                    HStack { Image(systemName: "chevron.left"); Spacer(); Text("2026年5月").font(FigmaFont.medium(12)); Spacer(); Image(systemName: "chevron.right") }.foregroundStyle(SmartPawStyle.brown.opacity(0.62)).padding(.vertical, 14)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                        ForEach(weekdays, id: \.self) { Text($0).font(FigmaFont.regular(8)).foregroundStyle(SmartPawStyle.brown.opacity(0.42)) }
                        ForEach(1...31, id: \.self) { day in
                            Text("\(day)").font(FigmaFont.regular(9)).foregroundStyle(day == 3 ? .white : SmartPawStyle.brown.opacity(0.62)).frame(width: 22, height: 22).background(day == 3 ? SmartPawStyle.brown : .clear, in: Circle())
                        }
                    }
                    .padding(12).background(SmartPawStyle.canvas.opacity(0.56), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    VStack(alignment: .leading, spacing: 10) {
                        Text("5月3日 · 0项计划").font(FigmaFont.medium(11))
                        Text("今天没有计划。点击 + 进行日程安排。 ").font(FigmaFont.regular(10)).foregroundStyle(SmartPawStyle.brown.opacity(0.45)).frame(maxWidth: .infinity, minHeight: 54).background(SmartPawStyle.canvas.opacity(0.55), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                        Text("本周即将到来").font(FigmaFont.medium(11)).padding(.top, 4)
                        ForEach(viewModel.scheduleItems) { item in
                            ProfileScheduleRow(item: item)
                        }
                    }
                    .foregroundStyle(SmartPawStyle.brown).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 17).padding(.bottom, 34)
                }
                .padding(.horizontal, 18)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FigmaBottomBar(selection: $viewModel.selectedTab)
        }
    }
}

private struct ProfileScheduleRow: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let item: ScheduleItem
    var body: some View { HStack(spacing: 9) { Text(item.dueDate.formatted(.dateTime.month().day())).font(FigmaFont.medium(9)).foregroundStyle(SmartPawStyle.brown.opacity(0.55)).frame(width: 42, height: 31).background(SmartPawStyle.canvas, in: RoundedRectangle(cornerRadius: 8, style: .continuous)); VStack(alignment: .leading, spacing: 2) { Text(item.title).font(FigmaFont.medium(10)); Text(item.spaceName).font(FigmaFont.regular(8)).foregroundStyle(SmartPawStyle.brown.opacity(0.45)) }; Spacer(); Button { viewModel.toggleScheduleItem(item.id) } label: { Circle().fill(item.isDone ? SmartPawStyle.mint : SmartPawStyle.orange).frame(width: 8, height: 8) }.buttonStyle(.plain) }.padding(.vertical, 4) }
}

private struct ProfileScheduleItem: Identifiable {
    let id: String
    let dateText: String
    let title: String
    let spaceName: String

    static let figmaItems = [
        ProfileScheduleItem(id: "closet", dateText: "5月6", title: "迷你衣橱整理", spaceName: "卧室"),
        ProfileScheduleItem(id: "cabinet", dateText: "5月7", title: "5分钟柜体重置", spaceName: "客厅"),
        ProfileScheduleItem(id: "living", dateText: "5月8", title: "周末方案回收", spaceName: "社区复刻")
    ]
}

private struct ProfileNavigation: View {
    let title: String
    let trailing: String
    let onBack: () -> Void
    var onTrailing: () -> Void = {}
    var body: some View { HStack { Button(action: onBack) { Image(systemName: "chevron.left").font(.system(size: 12, weight: .semibold)).frame(width: 32, height: 40) }.buttonStyle(.plain); Spacer(); Text(title).font(FigmaFont.medium(12)); Spacer(); Button(action: onTrailing) { Image(systemName: trailing).font(.system(size: 12, weight: .medium)).frame(width: 32, height: 40) }.buttonStyle(.plain) }.foregroundStyle(SmartPawStyle.brown) }
}

struct ProfileBadge: Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let symbol: String
    let color: Color
    let isLocked: Bool
    let assetName: String?

    init(id: String, title: String, description: String, symbol: String, color: Color, isLocked: Bool, assetName: String?) {
        self.id = id
        self.title = title
        self.description = description
        self.symbol = symbol
        self.color = color
        self.isLocked = isLocked
        self.assetName = assetName
    }

    static let samples: [ProfileBadge] = [
        .init(id: "tidy", title: "整洁的浣熊", description: "完成第一个区域整理", symbol: "pawprint.fill", color: ProfilePalette.mutedBlue, isLocked: false, assetName: "FigmaCompletion"),
        .init(id: "fresh", title: "闪闪发亮", description: "连续三天保持整洁", symbol: "sparkles", color: ProfilePalette.gold, isLocked: false, assetName: nil),
        .init(id: "champion", title: "冠军", description: "完成五个收纳计划", symbol: "trophy.fill", color: ProfilePalette.orange, isLocked: false, assetName: "FigmaProfileBadgeTrophy"),
        .init(id: "leaf", title: "整洁绿洲", description: "完成一个完整空间", symbol: "leaf.fill", color: ProfilePalette.mint, isLocked: false, assetName: "FigmaProfileBadgeLeaf"),
        .init(id: "box", title: "收纳大师", description: "整理超过二十件物品", symbol: "shippingbox.fill", color: ProfilePalette.orange, isLocked: false, assetName: "FigmaProfileBadgeBox"),
        .init(id: "target", title: "靶心", description: "完成一次深度整理", symbol: "target", color: ProfilePalette.orange, isLocked: false, assetName: nil),
        .init(id: "diamond", title: "钻石", description: "完成七个收纳计划", symbol: "diamond.fill", color: ProfilePalette.mutedBlue, isLocked: false, assetName: "FigmaProfileBadgeDiamond"),
        .init(id: "speed", title: "速跑", description: "在计划时间内完成整理", symbol: "bolt.fill", color: ProfilePalette.gold, isLocked: true, assetName: nil),
        .init(id: "mind", title: "读心术", description: "连续三次完成日程", symbol: "brain.head.profile", color: ProfilePalette.mutedBlue, isLocked: true, assetName: nil),
        .init(id: "journal", title: "日志", description: "记录五个完成空间", symbol: "book.closed.fill", color: ProfilePalette.mutedBlue, isLocked: true, assetName: nil),
        .init(id: "fire", title: "烈焰", description: "连续七天整理", symbol: "flame.fill", color: ProfilePalette.orange, isLocked: true, assetName: nil),
        .init(id: "wand", title: "魔法", description: "完成一个智能方案", symbol: "wand.and.stars", color: ProfilePalette.mutedBlue, isLocked: true, assetName: nil)
    ]

    @MainActor static func from(achievements: [Achievement], viewModel: AppViewModel) -> [ProfileBadge] {
        let source = achievements.isEmpty ? samples.map { Achievement(title: $0.title, subtitle: $0.description, iconName: $0.symbol) } : achievements
        return source.enumerated().map { index, achievement in
            let sample = samples.first(where: { $0.title == achievement.title }) ?? samples[index % samples.count]
            return ProfileBadge(id: achievement.id.uuidString, title: achievement.title, description: achievement.subtitle,
                                symbol: achievement.iconName.isEmpty ? sample.symbol : achievement.iconName,
                                color: sample.color, isLocked: !viewModel.isAchievementUnlocked(achievement), assetName: sample.assetName)
        }
    }
}

private enum ProfilePalette {
    static let mutedBlue = Color(red: 0.57, green: 0.66, blue: 0.76)
    static let mint = Color(red: 0.48, green: 0.70, blue: 0.56)
    static let gold = Color(red: 0.88, green: 0.71, blue: 0.31)
    static let orange = SmartPawStyle.orange
    static let brownGradient = LinearGradient(colors: [Color(red: 0.47, green: 0.32, blue: 0.23), Color(red: 0.30, green: 0.22, blue: 0.18)], startPoint: .topLeading, endPoint: .bottomTrailing)
}
