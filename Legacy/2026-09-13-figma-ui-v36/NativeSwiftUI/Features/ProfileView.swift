import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var destination: ProfileDestination?

    var body: some View {
        ProfileFigmaHub(
            onPlans: { destination = .plans },
            onBadges: { destination = .badges },
            onSavedPosts: { destination = .savedPosts }
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
            case .savedPosts:
                ProfileFigmaSavedPostsView(onDismiss: { destination = nil })
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
    case savedPosts
    case badgeDetail(ProfileBadge)

    var id: String {
        switch self {
        case .plans: "plans"
        case .badges: "badges"
        case .schedule: "schedule"
        case .savedPosts: "saved-posts"
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
            SmartPawProfileAvatar(size: 62)
            Text("Sarah Chen")
                .font(FigmaFont.medium(16))
                .foregroundStyle(SmartPawStyle.brown)
            Text("@sarah · Joined May 2026")
                .font(FigmaFont.regular(10))
                .foregroundStyle(SmartPawStyle.brown.opacity(0.45))
            Text("Level 4 · Tidy Master")
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
            ProfileMetric(value: "\(viewModel.catalogItems.count)", label: "Tracked items")
            ProfileMetric(value: "\(viewModel.completedCount)", label: "Organized spaces")
            ProfileMetric(value: "\(viewModel.achievements.filter { viewModel.isAchievementUnlocked($0) }.count)", label: "Badges earned")
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) { Rectangle().fill(SmartPawStyle.hairline).frame(height: 1) }
    }

    private var badgeStrip: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("Badges")
                    .font(FigmaFont.medium(12))
                Spacer()
                Button("View all", action: onBadges)
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
            ProfileListRow(
                icon: "calendar",
                title: "My plans",
                subtitle: viewModel.language == .english
                    ? "\(viewModel.spaces.filter { $0.activePlan != nil }.count) active"
                    : "\(viewModel.spaces.filter { $0.activePlan != nil }.count) 个进行中",
                action: onPlans
            )
            ProfileListRow(icon: "bookmark", title: "Saved posts", subtitle: "\(viewModel.favoriteCommunityCaseIDs.count)", action: onSavedPosts)
            ProfileListRow(icon: "person.2", title: "Friends", subtitle: "Invite and share")
        }
        .padding(.top, 9)
    }

    private var supportRows: some View {
        VStack(spacing: 0) {
            ProfileListRow(icon: "questionmark.circle", title: "Help & feedback")
            ProfileListRow(icon: "rectangle.portrait.and.arrow.right", title: "Sign out", isDestructive: true)
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
            Text(LocalizedStringKey(label)).font(FigmaFont.regular(9)).foregroundStyle(SmartPawStyle.brown.opacity(0.46))
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
                    Text(LocalizedStringKey(title)).font(FigmaFont.regular(12))
                    if let subtitle { Text(LocalizedStringKey(subtitle)).font(FigmaFont.regular(8)).foregroundStyle(SmartPawStyle.brown.opacity(0.45)) }
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

    private var allBadges: [ProfileBadge] {
        #if DEBUG
        if usesFigmaFixture {
            return ProfileBadge.samples
        }
        #endif
        return ProfileBadge.from(achievements: viewModel.achievements, viewModel: viewModel)
    }

    private var usesFigmaFixture: Bool {
        let arguments = CommandLine.arguments
        return arguments.contains("-SmartPawShowProfileBadges")
            || arguments.contains("-SmartPawShowProfileBadgeDetail")
            || arguments.contains("-SmartPawShowProfileLockedBadgeDetail")
    }

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
                    ProfileNavigation(title: "Badges", trailing: "square.and.arrow.up", onBack: onDismiss)
                    HStack(spacing: 11) {
                        Image(systemName: "diamond.fill").font(.system(size: 22)).foregroundStyle(.white)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Earned").font(FigmaFont.regular(9)).foregroundStyle(.white.opacity(0.72))
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
                            RarityLabel(title: "Common", color: ProfilePalette.mutedBlue)
                            RarityLabel(title: "Rare", color: ProfilePalette.mint)
                            RarityLabel(title: "Epic", color: ProfilePalette.orange)
                            RarityLabel(title: "Legendary", color: ProfilePalette.gold)
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
                Text(badge.isLocked ? "Badge locked" : badge.englishTitle).font(FigmaFont.medium(17)).foregroundStyle(SmartPawStyle.brown)
                Text(badge.englishDescription).font(FigmaFont.regular(10)).foregroundStyle(SmartPawStyle.brown.opacity(0.53)).multilineTextAlignment(.center)
                Text(badge.isLocked ? "Complete one storage plan to unlock" : "Earned April 12, 2026")
                    .font(FigmaFont.regular(9))
                    .foregroundStyle(SmartPawStyle.brown.opacity(0.45))
                    .padding(.horizontal, 10).frame(height: 22).background(SmartPawStyle.canvas, in: Capsule())
                Button(badge.isLocked ? "Complete a plan" : "Share badge") {
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
        case .all: "All"
        case .earned: "Earned"
        case .locked: "Locked"
        }
    }
}

private struct BadgeFilter: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(LocalizedStringKey(title)).font(FigmaFont.regular(10)).foregroundStyle(selected ? .white : SmartPawStyle.brown.opacity(0.58))
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
            Text(badge.englishTitle).font(FigmaFont.regular(9)).foregroundStyle(SmartPawStyle.brown.opacity(badge.isLocked ? 0.42 : 0.82)).lineLimit(1)
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
            Text(LocalizedStringKey(title)).font(FigmaFont.regular(8)).foregroundStyle(SmartPawStyle.brown.opacity(0.55))
        }
    }
}

// MARK: - 3. Plans and 4. Calendar

struct ProfileFigmaPlansView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let onDismiss: () -> Void
    var onSchedule: () -> Void = {}
    @State private var selectedSegment = "All"
    private let segments = ["All", "Active", "Completed"]

    private var plans: [ProfilePlan] {
        viewModel.spaces.flatMap { space in
            var result: [ProfilePlan] = []
            if let plan = space.activePlan {
                result.append(ProfilePlan(id: plan.id.uuidString, imageName: "FigmaProfilePlanCloset", status: "Active", spaceName: space.englishName, title: EnglishDisplay.text(plan.summary), progress: plan.progress, dateText: plan.timeBudget.englishTitle, isDone: false))
            }
                result += space.completedPlans.map { plan in
                ProfilePlan(id: plan.id.uuidString, imageName: "FigmaProfilePlanLiving", status: "Completed", spaceName: space.englishName, title: EnglishDisplay.text(plan.summary), progress: 1, dateText: plan.completedAt?.formatted(.dateTime.month().day()) ?? "Completed", isDone: true)
            }
            return result
        }
    }

    private var visiblePlans: [ProfilePlan] {
        switch selectedSegment {
        case "Active": plans.filter { !$0.isDone }
        case "Completed": plans.filter(\.isDone)
        default: plans
        }
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ProfileNavigation(
                        title: "My plans",
                        trailing: "plus",
                        onBack: onDismiss,
                        onTrailing: {
                            viewModel.addScheduleItem(
                                title: "New storage plan",
                                dueDate: Date().addingTimeInterval(86_400),
                                note: "Review the current storage state"
                            )
                            onSchedule()
                        }
                    )
                    HStack {
                        VStack(alignment: .leading, spacing: 3) { Text("This week").font(FigmaFont.regular(10)).foregroundStyle(.white.opacity(0.7)); Text("\(plans.filter { !$0.isDone }.count) active plans").font(FigmaFont.medium(17)).foregroundStyle(.white) }
                        Spacer()
                        Image(systemName: "calendar").font(.system(size: 17)).foregroundStyle(.white.opacity(0.84))
                    }
                    .padding(.horizontal, 16).frame(height: 70)
                    .background(ProfilePalette.brownGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.top, 9)
                    HStack(spacing: 7) {
                        ForEach(segments, id: \.self) { segment in
                            Button { selectedSegment = segment } label: { Text(LocalizedStringKey(segment)).font(FigmaFont.regular(9)).foregroundStyle(selectedSegment == segment ? .white : SmartPawStyle.brown.opacity(0.55)).padding(.horizontal, 11).frame(height: 25).background(selectedSegment == segment ? SmartPawStyle.orange : SmartPawStyle.canvas, in: Capsule()) }.buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 12)
                    ForEach(visiblePlans) { plan in
                        ProfilePlanCard(plan: plan) {
                            viewModel.continueActivePlan()
                            viewModel.showMessage(plan.isDone ? "This plan is complete" : "Back in the space to continue \(plan.title)")
                        }
                            .padding(.bottom, 9)
                    }
                    Button(action: onSchedule) { Label("View schedule", systemImage: "calendar").font(FigmaFont.medium(12)).foregroundStyle(SmartPawStyle.brown).frame(maxWidth: .infinity, minHeight: 42).background(SmartPawStyle.canvas, in: RoundedRectangle(cornerRadius: 12, style: .continuous)) }
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
    @EnvironmentObject private var viewModel: AppViewModel
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
                    Text(viewModel.language == .english ? plan.status : (plan.isDone ? "已完成" : "进行中"))
                        .font(FigmaFont.medium(7))
                        .foregroundStyle(plan.isDone ? .white : SmartPawStyle.orange)
                        .padding(.horizontal, 5).frame(height: 14)
                        .background(plan.isDone ? SmartPawStyle.mint : SmartPawStyle.orange.opacity(0.12), in: Capsule())
                    Text(plan.spaceName).font(FigmaFont.regular(8)).foregroundStyle(SmartPawStyle.brown.opacity(0.48))
                }
                Text(plan.title).font(FigmaFont.medium(12)).foregroundStyle(SmartPawStyle.brown).lineLimit(1)
                ProgressView(value: plan.progress).tint(plan.isDone ? SmartPawStyle.mint : SmartPawStyle.orange).frame(width: 112)
                Text(plan.dateText).font(FigmaFont.regular(8)).foregroundStyle(SmartPawStyle.brown.opacity(0.45))
            }
            Spacer()
            Button(action: onToggle) {
                Text(viewModel.language == .english ? (plan.isDone ? "Completed" : "Continue") : (plan.isDone ? "已完成" : "继续"))
                    .font(FigmaFont.medium(9))
                    .foregroundStyle(plan.isDone ? SmartPawStyle.mint : .white)
                    .padding(.horizontal, 10)
                    .frame(height: 24)
                    .background(plan.isDone ? SmartPawStyle.mint.opacity(0.13) : SmartPawStyle.orange, in: Capsule())
            }
            .buttonStyle(.plain)
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

}

struct ProfileFigmaSavedPostsView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let onDismiss: () -> Void
    @State private var selectedCase: CommunityCase?

    private var savedCases: [CommunityCase] {
        viewModel.communityCases.filter { viewModel.favoriteCommunityCaseIDs.contains($0.id) }
    }

    var body: some View {
        ZStack {
            SmartPawStyle.canvas.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    ProfileNavigation(title: "Saved posts", trailing: nil, onBack: onDismiss)
                    if savedCases.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "bookmark")
                                .font(.system(size: 34, weight: .medium))
                                .foregroundStyle(SmartPawStyle.orange)
                            Text("No saved plans yet")
                                .font(FigmaFont.semibold(17))
                            Text("Save a plan from Community and it will appear here for a quick remix.")
                                .font(FigmaFont.regular(12))
                                .foregroundStyle(SmartPawStyle.brown.opacity(0.56))
                                .multilineTextAlignment(.center)
                        }
                        .foregroundStyle(SmartPawStyle.brown)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 100)
                    } else {
                        ForEach(savedCases) { item in
                            HStack(spacing: 10) {
                                CommunityFigmaCoverImage(item: item)
                                    .frame(width: 92, height: 82)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(item.englishTitle)
                                        .font(FigmaFont.medium(14))
                                        .foregroundStyle(SmartPawStyle.brown)
                                        .lineLimit(2)
                                    Text("@\(item.englishAuthor) · \(item.englishDuration)")
                                        .font(FigmaFont.regular(10))
                                        .foregroundStyle(SmartPawStyle.brown.opacity(0.52))
                                    Button("View and remix") { selectedCase = item }
                                        .font(FigmaFont.medium(11))
                                        .foregroundStyle(SmartPawStyle.orange)
                                }
                                Spacer(minLength: 0)
                                Button {
                                    viewModel.toggleCommunityFavorite(item.id)
                                } label: {
                                    Image(systemName: "bookmark.fill")
                                        .foregroundStyle(SmartPawStyle.orange)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Remove saved plan \(item.englishTitle)")
                            }
                            .padding(10)
                            .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 100)
            }
        }
        .fullScreenCover(item: $selectedCase) { item in
            CommunityFigmaCaseDetail(
                item: item,
                onDismiss: { selectedCase = nil },
                onShowComments: { viewModel.showMessage("Open the Community case page to view comments.") },
                onShowPlan: {
                    viewModel.replicate(item)
                    selectedCase = nil
                    onDismiss()
                }
            )
            .environmentObject(viewModel)
        }
    }
}

struct ProfileFigmaScheduleView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let onDismiss: () -> Void
    private let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private var calendar: Calendar { Calendar.current }
    @State private var displayedMonth = Calendar.current.startOfDay(for: Date())
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ProfileNavigation(title: "Schedule", trailing: "plus", onBack: onDismiss, onTrailing: { viewModel.addScheduleItem(title: "New storage plan", dueDate: Date().addingTimeInterval(86400), note: "Review the current storage state") })
                    HStack { VStack(alignment: .leading, spacing: 3) { Text("This month").font(FigmaFont.regular(10)).foregroundStyle(.white.opacity(0.72)); Text("\(viewModel.scheduleItems.count) plans").font(FigmaFont.medium(17)).foregroundStyle(.white) }; Spacer(); Image(systemName: "chart.bar.fill").foregroundStyle(.white.opacity(0.84)) }
                        .padding(.horizontal, 16).frame(height: 70).background(ProfilePalette.brownGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous)).padding(.top, 9)
                    HStack {
                        Button {
                            displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                        } label: {
                            Image(systemName: "chevron.left")
                                .frame(width: 32, height: 32)
                        }
                        Spacer()
                        Text(monthTitle).font(FigmaFont.medium(12))
                        Spacer()
                        Button {
                            displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                        } label: {
                            Image(systemName: "chevron.right")
                                .frame(width: 32, height: 32)
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(SmartPawStyle.brown.opacity(0.62))
                    .padding(.vertical, 14)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                        ForEach(weekdays, id: \.self) { Text(LocalizedStringKey($0)).font(FigmaFont.regular(8)).foregroundStyle(SmartPawStyle.brown.opacity(0.42)) }
                        ForEach(0..<leadingEmptyDays, id: \.self) { _ in
                            Color.clear.frame(width: 22, height: 22)
                        }
                        ForEach(monthDays, id: \.self) { day in
                            let date = date(for: day)
                            Button {
                                selectedDate = date
                            } label: {
                                Text("\(day)")
                                    .font(FigmaFont.regular(9))
                                    .foregroundStyle(calendar.isDate(date, inSameDayAs: selectedDate) ? .white : SmartPawStyle.brown.opacity(0.62))
                                    .frame(width: 22, height: 22)
                                    .background(calendar.isDate(date, inSameDayAs: selectedDate) ? SmartPawStyle.brown : .clear, in: Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(12).background(SmartPawStyle.canvas.opacity(0.56), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    VStack(alignment: .leading, spacing: 10) {
                        Text("\(selectedDate.formatted(.dateTime.month().day())) · \(selectedDayItems.count) plans").font(FigmaFont.medium(11))
                        if selectedDayItems.isEmpty {
                            Text("No plans for this day. Tap + to schedule storage work.")
                                .font(FigmaFont.regular(10))
                                .foregroundStyle(SmartPawStyle.brown.opacity(0.45))
                                .frame(maxWidth: .infinity, minHeight: 54)
                                .background(SmartPawStyle.canvas.opacity(0.55), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                        } else {
                            ForEach(selectedDayItems) { item in
                                ProfileScheduleRow(item: item)
                            }
                        }
                        Text("Coming up this week").font(FigmaFont.medium(11)).padding(.top, 4)
                        ForEach(upcomingItems) { item in
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

    private var monthTitle: String {
        let components = calendar.dateComponents([.year, .month], from: displayedMonth)
        if viewModel.language == .chinese {
            return "\(components.year ?? 0)年\(components.month ?? 0)月"
        }
        let month = calendar.monthSymbols[max(0, min((components.month ?? 1) - 1, calendar.monthSymbols.count - 1))]
        return "\(month) \(components.year ?? 0)"
    }

    private var monthDays: [Int] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth) else { return [1] }
        return Array(range)
    }

    private var leadingEmptyDays: Int {
        let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)) ?? displayedMonth
        return calendar.component(.weekday, from: firstDay) - 1
    }

    private func date(for day: Int) -> Date {
        calendar.date(bySetting: .day, value: day, of: displayedMonth) ?? displayedMonth
    }

    private var selectedDayItems: [ScheduleItem] {
        viewModel.scheduleItems.filter { calendar.isDate($0.dueDate, inSameDayAs: selectedDate) }
    }

    private var upcomingItems: [ScheduleItem] {
        viewModel.scheduleItems
            .filter { $0.dueDate >= selectedDate && !calendar.isDate($0.dueDate, inSameDayAs: selectedDate) }
            .sorted { $0.dueDate < $1.dueDate }
            .prefix(3)
            .map { $0 }
    }
}

private struct ProfileScheduleRow: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let item: ScheduleItem
    var body: some View { HStack(spacing: 9) { Text(item.dueDate.formatted(.dateTime.month().day())).font(FigmaFont.medium(9)).foregroundStyle(SmartPawStyle.brown.opacity(0.55)).frame(width: 42, height: 31).background(SmartPawStyle.canvas, in: RoundedRectangle(cornerRadius: 8, style: .continuous)); VStack(alignment: .leading, spacing: 2) { Text(item.englishTitle).font(FigmaFont.medium(10)); Text(item.englishSpaceName).font(FigmaFont.regular(8)).foregroundStyle(SmartPawStyle.brown.opacity(0.45)) }; Spacer(); Button { viewModel.toggleScheduleItem(item.id) } label: { Circle().fill(item.isDone ? SmartPawStyle.mint : SmartPawStyle.orange).frame(width: 8, height: 8) }.buttonStyle(.plain) }.padding(.vertical, 4) }
}

private struct ProfileNavigation: View {
    let title: String
    let trailing: String?
    let onBack: () -> Void
    var onTrailing: () -> Void = {}
    var body: some View { HStack { Button(action: onBack) { Image(systemName: "chevron.left").font(.system(size: 12, weight: .semibold)).frame(width: 32, height: 40) }.buttonStyle(.plain); Spacer(); Text(LocalizedStringKey(title)).font(FigmaFont.medium(12)); Spacer(); if let trailing { Button(action: onTrailing) { Image(systemName: trailing).font(.system(size: 12, weight: .medium)).frame(width: 32, height: 40) }.buttonStyle(.plain) } else { Color.clear.frame(width: 32, height: 40) } }.foregroundStyle(SmartPawStyle.brown) }
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
        .init(id: "tidy", title: "Tidy Explorer", description: "Complete your first zone", symbol: "pawprint.fill", color: ProfilePalette.mutedBlue, isLocked: false, assetName: "FigmaCompletion"),
        .init(id: "fresh", title: "Fresh Start", description: "Stay tidy for three days", symbol: "sparkles", color: ProfilePalette.gold, isLocked: false, assetName: nil),
        .init(id: "champion", title: "Champion", description: "Complete five storage plans", symbol: "trophy.fill", color: ProfilePalette.orange, isLocked: false, assetName: "FigmaProfileBadgeTrophy"),
        .init(id: "leaf", title: "Tidy Oasis", description: "Complete one full space", symbol: "leaf.fill", color: ProfilePalette.mint, isLocked: false, assetName: "FigmaProfileBadgeLeaf"),
        .init(id: "box", title: "Storage Master", description: "Organize more than twenty items", symbol: "shippingbox.fill", color: ProfilePalette.orange, isLocked: false, assetName: "FigmaProfileBadgeBox"),
        .init(id: "target", title: "Bullseye", description: "Complete one deep reset", symbol: "target", color: ProfilePalette.orange, isLocked: false, assetName: nil),
        .init(id: "diamond", title: "Diamond", description: "Complete seven storage plans", symbol: "diamond.fill", color: ProfilePalette.mutedBlue, isLocked: false, assetName: "FigmaProfileBadgeDiamond"),
        .init(id: "speed", title: "Speed Run", description: "Finish within your plan time", symbol: "bolt.fill", color: ProfilePalette.gold, isLocked: true, assetName: nil),
        .init(id: "mind", title: "Mind Reader", description: "Complete three scheduled tasks", symbol: "brain.head.profile", color: ProfilePalette.mutedBlue, isLocked: true, assetName: nil),
        .init(id: "journal", title: "Journal", description: "Record five completed spaces", symbol: "book.closed.fill", color: ProfilePalette.mutedBlue, isLocked: true, assetName: nil),
        .init(id: "fire", title: "On Fire", description: "Organize for seven days", symbol: "flame.fill", color: ProfilePalette.orange, isLocked: true, assetName: nil),
        .init(id: "wand", title: "Magic", description: "Complete one smart plan", symbol: "wand.and.stars", color: ProfilePalette.mutedBlue, isLocked: true, assetName: nil)
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
