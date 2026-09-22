import SwiftUI
import UIKit

/// SwiftUI translation of the current Figma Make Version 73 root experience.
/// The Make bundle remains in figma-ui-inventory as the source reference; this
/// layer keeps the app native while preserving its 390pt composition and flow.
struct MakeReplicaRootView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var tab: MakeReplicaTab = .spatial
    @State private var showsCapture = false
    @State private var captureOriginTab: MakeReplicaTab = .spatial
    @State private var categoryRoute: ItemCategory?
    @State private var route: MakeReplicaRoute?

    init() {
        #if DEBUG
        let arguments = CommandLine.arguments
        let initial: MakeReplicaTab
        if arguments.contains("-SmartPawShowMakeClassification") {
            initial = .classification
        } else if arguments.contains("-SmartPawShowMakeCommunity") {
            initial = .community
        } else if arguments.contains("-SmartPawShowMakeMine") {
            initial = .mine
        } else {
            initial = .spatial
        }
        _tab = State(initialValue: initial)
        if arguments.contains("-SmartPawShowMakeCategoryDetail") {
            _categoryRoute = State(initialValue: .books)
        }
        #endif
    }

    var body: some View {
        ZStack {
            SmartPawStyle.linen.ignoresSafeArea()

            VStack(spacing: 0) {
                Group {
                    if let category = categoryRoute {
                        MakeCategoryDetailScreen(
                            category: category,
                            onBack: { categoryRoute = nil },
                            onOpenCapture: {
                                captureOriginTab = .classification
                                categoryRoute = nil
                                viewModel.selectedTab = .capture
                                showsCapture = true
                            }
                        )
                        .environmentObject(viewModel)
                    } else {
                        switch tab {
                        case .spatial:
                            MakeSpatialScreen(
                                onOpenSpace: { route = .space },
                                onOpenProgress: { space in
                                    viewModel.selectSpace(space.id)
                                    route = .space
                                },
                                onOpenAttention: { space in
                                    viewModel.selectSpace(space.id)
                                    route = .spaceAttention(space)
                                }
                            )
                        case .classification:
                            MakeClassificationScreen(
                                onOpenCategory: { categoryRoute = $0 },
                                onOpenCapture: {
                                    captureOriginTab = .classification
                                    viewModel.selectedTab = .capture
                                    showsCapture = true
                                }
                            )
                        case .community:
                            MakeCommunityScreen()
                        case .mine:
                            MakeMineScreen(onRoute: { route = $0 })
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if categoryRoute == nil {
                    MakeReplicaBottomNav(active: $tab) {
                        captureOriginTab = tab
                        viewModel.selectedTab = .capture
                        showsCapture = true
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showsCapture) {
            CaptureView()
                .environmentObject(viewModel)
        }
        .fullScreenCover(item: $route) { destination in
            switch destination {
            case .space:
                SpaceView()
                    .environmentObject(viewModel)
            case let .spaceAttention(space):
                MakeSpaceAttentionView(
                    space: space,
                    onDismiss: { route = nil },
                    onRelight: {
                        viewModel.selectSpace(space.id)
                        route = nil
                        captureOriginTab = .spatial
                        viewModel.selectedTab = .capture
                        showsCapture = true
                    }
                )
                .environmentObject(viewModel)
            case .profile:
                ProfileView()
                    .environmentObject(viewModel)
            case .plans:
                ProfileFigmaPlansView(onDismiss: { route = nil }, onSchedule: { route = .schedule })
                    .environmentObject(viewModel)
            case .badges:
                ProfileFigmaBadgesView(onDismiss: { route = nil }) { badge in
                    route = .badgeDetail(badge)
                }
                    .environmentObject(viewModel)
            case let .badgeDetail(badge):
                ProfileFigmaBadgeDetailView(badge: badge, onDismiss: { route = .badges })
                    .environmentObject(viewModel)
            case .savedPosts:
                ProfileFigmaSavedPostsView(onDismiss: { route = nil })
                    .environmentObject(viewModel)
            case .schedule:
                ProfileFigmaScheduleView(onDismiss: { route = nil })
                    .environmentObject(viewModel)
            case .language:
                LanguageSettingsView(onDismiss: { route = nil })
                    .environmentObject(viewModel)
            case .friends:
                MakeInfoScreen(title: "Friends", icon: "person.2", onDismiss: { route = nil }) {
                    Text("Follow organizers you trust from Community and save their plans for a quick remix.")
                }
                .environmentObject(viewModel)
            case .help:
                MakeInfoScreen(title: "Help & feedback", icon: "questionmark.circle", onDismiss: { route = nil }) {
                    Text("Camera scans, photo imports, recognition review, and storage plans are all saved locally on this device.")
                }
                .environmentObject(viewModel)
            }
        }
        .onChange(of: showsCapture) { _, isPresented in
            if !isPresented {
                tab = captureOriginTab
                viewModel.selectedTab = captureOriginTab.appTab
            }
        }
        .onChange(of: tab) { _, newTab in
            viewModel.selectedTab = newTab.appTab
        }
    }
}

private enum MakeReplicaTab: Hashable {
    case spatial, classification, community, mine

    var appTab: AppTab {
        switch self {
        case .spatial: .space
        case .classification: .catalog
        case .community: .community
        case .mine: .profile
        }
    }
}

private enum MakeReplicaRoute: Identifiable {
    case space, spaceAttention(StorageSpace), profile, plans, badges, badgeDetail(ProfileBadge), savedPosts, schedule, language, friends, help

    var id: String {
        switch self {
        case .space: "space"
        case let .spaceAttention(space): "space-attention-\(space.id.uuidString)"
        case .profile: "profile"
        case .plans: "plans"
        case .badges: "badges"
        case let .badgeDetail(badge): "badge-\(badge.id)"
        case .savedPosts: "saved-posts"
        case .schedule: "schedule"
        case .language: "language"
        case .friends: "friends"
        case .help: "help"
        }
    }
}

private struct MakeInfoScreen<Content: View>: View {
    let title: String
    let icon: String
    let onDismiss: () -> Void
    let content: Content

    init(title: String, icon: String, onDismiss: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.onDismiss = onDismiss
        self.content = content()
    }

    var body: some View {
        ZStack {
            SmartPawStyle.canvas.ignoresSafeArea()
            VStack(spacing: 18) {
                HStack {
                    Button(action: onDismiss) {
                        Image(systemName: "chevron.left")
                            .frame(width: 40, height: 40)
                            .background(.white, in: Circle())
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text(LocalizedStringKey(title)).font(.system(size: 18, weight: .semibold))
                    Spacer()
                    Image(systemName: icon).frame(width: 40, height: 40)
                }
                .foregroundStyle(SmartPawStyle.brown)
                .padding(.horizontal, 24)
                .padding(.top, 54)

                Image(systemName: icon)
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(SmartPawStyle.orange)
                    .frame(width: 76, height: 76)
                    .background(.white, in: Circle())
                    .padding(.top, 30)
                content
                    .font(.system(size: 14))
                    .foregroundStyle(SmartPawStyle.brown.opacity(0.68))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 34)
                Spacer()
            }
        }
    }
}

private struct MakeReplicaBottomNav: View {
    @Binding var active: MakeReplicaTab
    let onCamera: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            navButton(.spatial, "house", "Spatial")
            navButton(.classification, "square.grid.3x3", "Classify")
            Color.clear.frame(width: 56)
            navButton(.community, "person.2", "Community")
            navButton(.mine, "person", "Mine")
        }
        .padding(.horizontal, 18)
        .frame(height: 74)
        .background(.white, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(alignment: .top) {
            Button(action: onCamera) {
                Image(systemName: "camera")
                    .font(.system(size: 25, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(SmartPawStyle.orange, in: Circle())
                    .shadow(color: SmartPawStyle.orange.opacity(0.35), radius: 14, y: 7)
            }
            .offset(y: -28)
            .accessibilityLabel("Open capture")
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    private func navButton(_ value: MakeReplicaTab, _ icon: String, _ title: String) -> some View {
        Button { active = value } label: {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 21, weight: .medium))
                Text(title).font(.system(size: 10, weight: .regular))
            }
            .foregroundStyle(active == value ? SmartPawStyle.orange : SmartPawStyle.brown.opacity(0.52))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

private struct MakeSpatialScreen: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let onOpenSpace: () -> Void
    let onOpenProgress: (StorageSpace) -> Void
    let onOpenAttention: (StorageSpace) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                MakeSpatialHeader()

                HStack(alignment: .firstTextBaseline) {
                    Text(viewModel.language == .english ? "Space map" : "空间地图")
                        .font(.system(size: 17, weight: .semibold))
                    Spacer()
                    Button(action: onOpenSpace) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(SmartPawStyle.orange)
                            .frame(width: 30, height: 30)
                            .background(.white, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(viewModel.language == .english ? "View all spaces" : "查看全部空间")
                }
                .foregroundStyle(SmartPawStyle.brown)
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 12)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(homeSpacePreviews) { preview in
                        MakeSpaceMapCard(preview: preview) {
                            if let source = preview.source {
                                viewModel.selectSpace(source.id)
                                if preview.needsAttention {
                                    onOpenAttention(source)
                                    return
                                }
                            }
                            onOpenSpace()
                        }
                    }
                }
                .padding(.horizontal, 24)

                HStack(alignment: .firstTextBaseline) {
                    Text(viewModel.language == .english ? "Tidying assistant" : "整理助手")
                        .font(.system(size: 17, weight: .semibold))
                    Spacer()
                    Text(viewModel.language == .english ? "Keep going" : "继续整理")
                        .font(.system(size: 12))
                        .foregroundStyle(SmartPawStyle.brown.opacity(0.52))
                }
                .foregroundStyle(SmartPawStyle.brown)
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 12)

                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(SmartPawStyle.orange)
                            .frame(width: 38, height: 38)
                            .background(SmartPawStyle.tan, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        Text(viewModel.language == .english
                             ? "4 spaces collected · Your home is taking shape"
                             : "已收集 4 个空间 · 我的家正在慢慢成形")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(SmartPawStyle.brown)
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    MakeAssistantProgressRow(
                        title: viewModel.language == .english ? "Bathroom" : "浴室",
                        subtitle: viewModel.language == .english ? "In progress" : "正在进行中",
                        progress: 0.35,
                        onTap: onOpenSpace
                    )
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 122)
        }
    }

    private var activeAction: String {
        let count = viewModel.spaces.filter { $0.activePlan != nil }.count
        return viewModel.language == .english ? "\(count) active" : "\(count) 个进行中"
    }

    private var homeSpacePreviews: [MakeHomeSpacePreview] {
        return [
            MakeHomeSpacePreview(id: "sofa", title: "懒人沙发区", emoji: "🛋️", style: .sofa, age: nil, source: source(at: 0)),
            MakeHomeSpacePreview(id: "desk", title: "我的书桌", emoji: "🖥️", style: .desk, age: nil, source: source(at: 1)),
            MakeHomeSpacePreview(id: "balcony", title: "晒太阳的阳台", emoji: "🪴", style: .balcony, age: 26, source: source(at: 0)),
            MakeHomeSpacePreview(id: "bedroom", title: "小卧室", emoji: "🛏️", style: .bedroom, age: 48, source: source(at: 1))
        ]
    }

    private func source(at index: Int) -> StorageSpace? {
        guard viewModel.spaces.indices.contains(index) else { return nil }
        return viewModel.spaces[index]
    }
}

private struct MakeHomeSpacePreview: Identifiable {
    let id: String
    let title: String
    let emoji: String
    let style: MakeRoomStyle
    let age: Int?
    let source: StorageSpace?

    var needsAttention: Bool { age != nil }
}

private struct MakeAssistantProgressRow: View {
    let title: String
    let subtitle: String
    let progress: Double
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(SmartPawStyle.blue)
                    .frame(width: 38, height: 38)
                    .background(SmartPawStyle.blue.opacity(0.2), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(title).font(.system(size: 13, weight: .semibold))
                        Spacer()
                        Text("35%").font(.system(size: 11, weight: .semibold)).foregroundStyle(SmartPawStyle.orange)
                    }
                    Text(subtitle).font(.system(size: 10)).foregroundStyle(SmartPawStyle.brown.opacity(0.5))
                    ProgressView(value: progress)
                        .tint(SmartPawStyle.orange)
                }
            }
            .foregroundStyle(SmartPawStyle.brown)
            .padding(12)
        }
        .buttonStyle(.plain)
        .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct MakeSpatialHeader: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        HStack(spacing: 12) {
            BrandBadge(size: 42)
            VStack(alignment: .leading, spacing: 3) {
                Text(viewModel.language == .english ? "My home" : "我的家")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(SmartPawStyle.brown)
            }
            Spacer(minLength: 0)
            Image(systemName: "bell.badge")
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(SmartPawStyle.brown)
                .frame(width: 42, height: 42)
                .background(.white, in: Circle())
        }
        .padding(.horizontal, 24)
        .padding(.top, 54)
        .padding(.bottom, 6)
    }
}

private struct MakeSpaceMapCard: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let preview: MakeHomeSpacePreview
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    MakeRoomIllustration(style: preview.style, isMuted: preview.needsAttention)
                        .frame(maxWidth: .infinity)
                        .frame(height: 112)

                    if let age = preview.age {
                        Text(viewModel.language == .english ? "\(age)d" : "\(age) 天")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .frame(height: 23)
                            .background(SmartPawStyle.orange, in: Capsule())
                            .padding(8)
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(viewModel.language == .english ? preview.title : preview.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Text(preview.emoji)
                        .font(.system(size: 13))
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(SmartPawStyle.brown.opacity(0.35))
                }
                .foregroundStyle(SmartPawStyle.brown)
                .padding(.horizontal, 11)
                .padding(.top, 10)

                Text(preview.needsAttention
                     ? (viewModel.language == .english ? "Needs attention" : "需要重新整理")
                     : (viewModel.language == .english ? "Organized" : "已整理"))
                    .font(.system(size: 10))
                    .foregroundStyle(preview.needsAttention ? SmartPawStyle.orange : SmartPawStyle.brown.opacity(0.52))
                    .lineLimit(1)
                    .padding(.horizontal, 11)
                    .padding(.top, 3)
                    .padding(.bottom, 11)
            }
        }
        .buttonStyle(.plain)
        .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .clipped()
        .shadow(color: SmartPawStyle.brown.opacity(0.05), radius: 9, y: 3)
    }
}

private struct MakeAssistantRow: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let space: StorageSpace
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                MakeRoomIllustration(style: space.makeRoomStyle, isMuted: false)
                    .frame(width: 62, height: 62)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Text(viewModel.language == .english ? space.englishName : space.name)
                            .font(.system(size: 13, weight: .semibold))
                        Text(space.makeEmoji)
                            .font(.system(size: 12))
                        Spacer(minLength: 0)
                        Text("\(Int(((space.activePlan?.progress ?? 0) * 100).rounded()))%")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(SmartPawStyle.orange)
                    }
                    Text(viewModel.language == .english ? "In progress" : "正在进行中")
                        .font(.system(size: 10))
                        .foregroundStyle(SmartPawStyle.brown.opacity(0.5))
                    ProgressView(value: space.activePlan?.progress ?? 0)
                        .tint(SmartPawStyle.orange)
                }
            }
            .foregroundStyle(SmartPawStyle.brown)
            .padding(12)
        }
        .buttonStyle(.plain)
        .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private enum MakeRoomStyle {
    case sofa, desk, balcony, bedroom, pantry

    var symbol: String {
        switch self {
        case .sofa: "sofa"
        case .desk: "desktopcomputer"
        case .balcony: "leaf.fill"
        case .bedroom: "bed.double.fill"
        case .pantry: "shippingbox.fill"
        }
    }

    var accent: Color {
        switch self {
        case .sofa: Color(red: 0.77, green: 0.63, blue: 0.50)
        case .desk: SmartPawStyle.blue
        case .balcony: SmartPawStyle.mint
        case .bedroom: Color(red: 0.82, green: 0.65, blue: 0.68)
        case .pantry: SmartPawStyle.orange
        }
    }
}

private struct MakeRoomIllustration: View {
    let style: MakeRoomStyle
    let isMuted: Bool

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            ZStack {
                SmartPawStyle.soft.opacity(isMuted ? 0.56 : 0.76)

                Path { path in
                    path.move(to: CGPoint(x: 0, y: height * 0.22))
                    path.addLine(to: CGPoint(x: width * 0.48, y: height * 0.06))
                    path.addLine(to: CGPoint(x: width * 0.48, y: height * 0.41))
                    path.addLine(to: CGPoint(x: 0, y: height * 0.57))
                    path.closeSubpath()
                }
                .fill(Color.white.opacity(0.54))

                Path { path in
                    path.move(to: CGPoint(x: width * 0.48, y: height * 0.06))
                    path.addLine(to: CGPoint(x: width, y: height * 0.22))
                    path.addLine(to: CGPoint(x: width, y: height * 0.57))
                    path.addLine(to: CGPoint(x: width * 0.48, y: height * 0.41))
                    path.closeSubpath()
                }
                .fill(Color.white.opacity(0.82))

                Path { path in
                    path.move(to: CGPoint(x: 0, y: height * 0.57))
                    path.addLine(to: CGPoint(x: width, y: height * 0.57))
                    path.addLine(to: CGPoint(x: width * 0.77, y: height))
                    path.addLine(to: CGPoint(x: width * 0.23, y: height))
                    path.closeSubpath()
                }
                .fill(SmartPawStyle.canvas.opacity(isMuted ? 0.7 : 1))

                Path { path in
                    path.move(to: CGPoint(x: width * 0.23, y: height))
                    path.addLine(to: CGPoint(x: width * 0.5, y: height * 0.57))
                    path.addLine(to: CGPoint(x: width * 0.77, y: height))
                }
                .stroke(SmartPawStyle.brown.opacity(0.12), lineWidth: 1)

                Image(systemName: style.symbol)
                    .font(.system(size: min(width, height) * 0.28, weight: .semibold))
                    .foregroundStyle(style.accent.opacity(isMuted ? 0.48 : 0.9))
                    .frame(width: width * 0.3, height: height * 0.22)
                    .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .rotationEffect(.degrees(-4))
                    .offset(x: width * 0.03, y: height * 0.18)

                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(style.accent.opacity(isMuted ? 0.35 : 0.7))
                    .frame(width: width * 0.38, height: height * 0.12)
                    .rotationEffect(.degrees(-11))
                    .offset(x: width * 0.2, y: height * 0.36)
            }
            .opacity(isMuted ? 0.84 : 1)
        }
        .clipped()
    }
}

private extension StorageSpace {
    var makeDaysSinceLastOrganized: Int {
        guard let date = lastOrganizedAt ?? completedPlans.compactMap(\.completedAt).max() else { return 0 }
        return max(0, Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0)
    }

    var makeIsExpired: Bool {
        activePlan == nil && makeDaysSinceLastOrganized >= 14
    }

    var makeEmoji: String {
        let value = name.lowercased()
        if value.contains("床") || value.contains("卧") || value.contains("bed") { return "🛏️" }
        if value.contains("阳台") || value.contains("balcony") { return "🪴" }
        if value.contains("书桌") || value.contains("桌") || value.contains("desk") { return "🖥️" }
        if value.contains("沙发") || value.contains("客厅") || value.contains("living") { return "🛋️" }
        return "📦"
    }

    var makeRoomStyle: MakeRoomStyle {
        switch makeEmoji {
        case "🛏️": .bedroom
        case "🪴": .balcony
        case "🖥️": .desk
        case "🛋️": .sofa
        default: .pantry
        }
    }

    func makeStatusText(isEnglish: Bool) -> String {
        if activePlan != nil {
            let progress = Int(((activePlan?.progress ?? 0) * 100).rounded())
            return isEnglish ? "In progress · \(progress)%" : "正在进行中 · \(progress)%"
        }
        if makeIsExpired {
            return isEnglish ? "Needs attention" : "需要重新整理"
        }
        if hasVerifiedComparison || !completedPlans.isEmpty {
            return isEnglish ? "Organized · \(detectedItems.count) items" : "已整理 · \(detectedItems.count) 件物品"
        }
        return isEnglish ? "Ready to scan" : "等待第一次整理"
    }
}

private struct MakeSpaceAttentionView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let space: StorageSpace
    let onDismiss: () -> Void
    let onRelight: () -> Void

    var body: some View {
        ZStack {
            SmartPawStyle.canvas.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button(action: onDismiss) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(SmartPawStyle.brown)
                            .frame(width: 38, height: 38)
                            .background(.white, in: Circle())
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text(viewModel.language == .english ? "Refresh space" : "点亮空间")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(SmartPawStyle.brown)
                    Spacer()
                    Color.clear.frame(width: 38, height: 38)
                }
                .padding(.horizontal, 24)
                .padding(.top, 54)

                MakeRoomIllustration(style: space.makeRoomStyle, isMuted: true)
                    .frame(height: 190)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.horizontal, 24)
                    .padding(.top, 26)

                VStack(alignment: .leading, spacing: 10) {
                    Text(viewModel.language == .english ? "Your space is waiting for a reset" : "这个空间等你重新整理")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(SmartPawStyle.brown)
                    Text(viewModel.language == .english
                         ? "It has been \(space.makeDaysSinceLastOrganized) days since the last completed plan. Start with a new scan and bring the room back to life."
                         : "距离上次完成整理已经 \(space.makeDaysSinceLastOrganized) 天。重新拍摄或导入照片，就可以继续整理这个空间。")
                        .font(.system(size: 14))
                        .foregroundStyle(SmartPawStyle.brown.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                Spacer()

                Button(action: onRelight) {
                    Label(viewModel.language == .english ? "Start a new scan" : "重新拍摄并点亮", systemImage: "camera.viewfinder")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 12)

                Button(viewModel.language == .english ? "Later" : "稍后再说", action: onDismiss)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(SmartPawStyle.brown.opacity(0.58))
                    .frame(maxWidth: .infinity, minHeight: 38)
                    .buttonStyle(.plain)
                    .padding(.bottom, 26)
            }
        }
    }
}

private struct MakeHeader: View {
    let eyebrow: String
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(.white)
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(SmartPawStyle.orange)
            }
            .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(LocalizedStringKey(eyebrow)).font(.system(size: 12)).foregroundStyle(SmartPawStyle.brown.opacity(0.55))
                Text(LocalizedStringKey(title)).font(.system(size: 18, weight: .semibold)).foregroundStyle(SmartPawStyle.brown)
            }
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(SmartPawStyle.brown)
                .frame(width: 44, height: 44)
                .background(.white, in: Circle())
        }
        .padding(.horizontal, 24)
        .padding(.top, 54)
        .padding(.bottom, 8)
    }
}

private struct MakeProgressCard: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let progress: Int

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().stroke(SmartPawStyle.soft, lineWidth: 12)
                Circle()
                    .trim(from: 0, to: CGFloat(progress) / 100)
                    .stroke(SmartPawStyle.orange, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text("\(progress)%").font(.system(size: 28, weight: .semibold))
                    Text("Storage Progress").font(.system(size: 10))
                }
                .foregroundStyle(SmartPawStyle.brown)
            }
            .frame(width: 148, height: 148)
            VStack(alignment: .leading, spacing: 8) {
                Text("This week").font(.system(size: 12)).foregroundStyle(SmartPawStyle.brown.opacity(0.55))
                Text("Keep going!").font(.system(size: 17, weight: .semibold)).foregroundStyle(SmartPawStyle.brown)
                HStack(spacing: 6) {
                    MakeProgressPill(text: viewModel.language == .english ? "\(progress == 0 ? 0 : 1) spaces" : "\(progress == 0 ? 0 : 1) 个空间", color: SmartPawStyle.canvas)
                    MakeProgressPill(text: viewModel.language == .english ? "+5 done" : "+5 已完成", color: SmartPawStyle.blue)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(24)
        .background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: SmartPawStyle.brown.opacity(0.06), radius: 12, y: 4)
        .padding(.horizontal, 24)
        .padding(.top, 18)
    }
}

private struct MakeProgressPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(verbatim: text)
            .font(.system(size: 11))
            .foregroundStyle(SmartPawStyle.brown)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(color, in: Capsule())
    }
}

private struct MakeSpaceCard: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let space: StorageSpace
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
            MakeAssetImage(name: space.beforeAssetName ?? space.beforeImageName)
                .frame(width: 200, height: 128)
                .clipped()
            VStack(alignment: .leading, spacing: 3) {
                Text(viewModel.language == .english ? space.englishName : space.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(SmartPawStyle.brown)
                Text("\(space.detectedItems.count) \(itemUnit) · \(progressText)")
                    .font(.system(size: 11)).foregroundStyle(SmartPawStyle.brown.opacity(0.55))
            }
            .padding(14)
            }
        }
        .buttonStyle(.plain)
        .frame(width: 200)
        .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .clipped()
    }

    private var progressText: String {
        guard let plan = space.activePlan else { return space.completedPlans.isEmpty ? "0%" : "100%" }
        return "\(Int(plan.progress * 100))%"
    }

    private var itemUnit: String {
        viewModel.language == .english ? "items" : "件物品"
    }
}

private struct MakeProgressRow: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let space: StorageSpace
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
            MakeAssetImage(name: space.beforeAssetName ?? space.beforeImageName)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.language == .english ? space.englishName : space.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(SmartPawStyle.brown)
                ProgressView(value: space.activePlan?.progress ?? 0)
                    .tint(SmartPawStyle.orange)
            }
            Spacer()
            Text("\(Int((space.activePlan?.progress ?? 0) * 100))%")
                .font(.system(size: 11)).foregroundStyle(SmartPawStyle.brown.opacity(0.6))
            }
        }
        .buttonStyle(.plain)
        .padding(12)
        .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct MakeClassificationScreen: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var searchText = ""
    @State private var isEditing = false
    @State private var selectedItemIDs: Set<UUID> = []
    let onOpenCategory: (ItemCategory) -> Void
    let onOpenCapture: () -> Void

    private var categories: [(ItemCategory, Color)] {
        [(.clothes, SmartPawStyle.blue), (.books, Color(red: 0.85, green: 0.76, blue: 0.66)), (.trash, Color(red: 0.80, green: 0.66, blue: 0.55)), (.electronics, Color(red: 0.72, green: 0.62, blue: 0.52)), (.toys, Color(red: 0.70, green: 0.83, blue: 0.78)), (.tools, Color(red: 0.66, green: 0.72, blue: 0.80))]
    }

    private var filteredItems: [DetectedItem] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return viewModel.catalogItems }
        return viewModel.catalogItems.filter {
            $0.name.localizedCaseInsensitiveContains(keyword)
                || $0.category.rawValue.localizedCaseInsensitiveContains(keyword)
                || $0.suggestedZone.localizedCaseInsensitiveContains(keyword)
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("All your items").font(.system(size: 12)).foregroundStyle(SmartPawStyle.brown.opacity(0.55))
                        Text("Classification").font(.system(size: 24, weight: .semibold)).foregroundStyle(SmartPawStyle.brown)
                    }
                    Spacer()
                    Button(isEditing ? "Done" : "Edit") {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            isEditing.toggle()
                            if !isEditing { selectedItemIDs.removeAll() }
                        }
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(SmartPawStyle.orange)
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.top, 54)
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(SmartPawStyle.brown.opacity(0.65))
                    TextField("Search items or categories…", text: $searchText)
                    MakePill(text: "AI tags", color: SmartPawStyle.canvas)
                }
                .padding(.horizontal, 18)
                .frame(height: 56)
                .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding(.horizontal, 24)
                .padding(.top, 18)
                MakeAIClassificationBanner(onTap: onOpenCapture)
                MakeSectionHeader(title: "Categories", action: "\(categories.count)", isActionEnabled: false, onAction: {})
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(categories, id: \.0.id) { category, color in
                        MakeCategoryCard(category: category, color: color, count: filteredItems.filter { $0.category == category }.count, onTap: { onOpenCategory(category) })
                    }
                }
                .padding(.horizontal, 24)
                HStack {
                    Text(LocalizedStringKey("Recently tagged"))
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                    if isEditing, !selectedItemIDs.isEmpty {
                        Button("Delete") {
                            selectedItemIDs.forEach(viewModel.removeCatalogItem)
                            selectedItemIDs.removeAll()
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.red)
                        .buttonStyle(.plain)
                    } else {
                        Button(isEditing ? "Done" : "Edit") {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                isEditing.toggle()
                                if !isEditing { selectedItemIDs.removeAll() }
                            }
                        }
                        .font(.system(size: 12))
                        .foregroundStyle(SmartPawStyle.orange)
                        .buttonStyle(.plain)
                    }
                }
                .foregroundStyle(SmartPawStyle.brown)
                .padding(.horizontal, 24)
                .padding(.top, 26)
                .padding(.bottom, 12)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                    ForEach(Array(filteredItems.prefix(6))) { item in
                        MakeRecentItem(
                            item: item,
                            isEditing: isEditing,
                            isSelected: selectedItemIDs.contains(item.id),
                            onTap: {
                                if isEditing {
                                    if selectedItemIDs.contains(item.id) {
                                        selectedItemIDs.remove(item.id)
                                    } else {
                                        selectedItemIDs.insert(item.id)
                                    }
                                } else {
                                    onOpenCategory(item.category)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 122)
        }
    }
}

private struct MakeCategoryDetailScreen: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var isEditing = false
    let category: ItemCategory
    let onBack: () -> Void
    let onOpenCapture: () -> Void

    private var items: [DetectedItem] {
        viewModel.catalogItems.filter { $0.category == category }
    }

    private var categoryName: String {
        viewModel.language == .english ? category.englishName : category.rawValue
    }

    private func categoryIcon(_ category: ItemCategory) -> String {
        switch category {
        case .books: "books.vertical.fill"
        case .electronics: "ipad.and.iphone"
        case .stationery: "pencil.and.ruler.fill"
        case .clothes: "tshirt.fill"
        case .toys: "gift.fill"
        case .trash: "trash.fill"
        case .tools: "shippingbox.fill"
        }
    }

    var body: some View {
        ZStack {
            SmartPawStyle.linen.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(SmartPawStyle.brown)
                            .frame(width: 38, height: 38)
                            .background(.white, in: Circle())
                    }
                    .buttonStyle(.plain)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Classification")
                            .font(.system(size: 10))
                            .foregroundStyle(SmartPawStyle.brown.opacity(0.48))
                        Text(categoryName)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(SmartPawStyle.brown)
                    }
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) { isEditing.toggle() }
                    } label: {
                        Text(isEditing ? "Done" : "Edit")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(SmartPawStyle.orange)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.top, 54)
                .padding(.bottom, 12)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            Image(systemName: categoryIcon(category))
                                .font(.system(size: 19, weight: .medium))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(SmartPawStyle.orange, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(categoryName)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(SmartPawStyle.brown)
                                Text(viewModel.language == .english ? "\(items.count) items" : "\(items.count) 件物品")
                                    .font(.system(size: 11))
                                    .foregroundStyle(SmartPawStyle.brown.opacity(0.52))
                            }
                            Spacer()
                        }
                        .padding(14)
                        .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                        Text(viewModel.language == .english ? "Items in this category" : "分类中的物品")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(SmartPawStyle.brown)

                        if items.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "shippingbox")
                                    .font(.system(size: 28, weight: .medium))
                                    .foregroundStyle(SmartPawStyle.orange)
                                Text("This category has no items yet.")
                                    .font(.system(size: 12))
                                    .foregroundStyle(SmartPawStyle.brown.opacity(0.56))
                            }
                            .frame(maxWidth: .infinity, minHeight: 150)
                            .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        } else {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(items) { item in
                                    VStack(alignment: .leading, spacing: 7) {
                                        Image(systemName: categoryIcon(category))
                                            .font(.system(size: 20, weight: .medium))
                                            .foregroundStyle(SmartPawStyle.orange)
                                            .frame(maxWidth: .infinity, minHeight: 70)
                                            .background(SmartPawStyle.soft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        Text(viewModel.language == .english ? item.englishName : item.name)
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundStyle(SmartPawStyle.brown)
                                            .lineLimit(2)
                                        Text(viewModel.language == .english ? item.englishZone : item.suggestedZone)
                                            .font(.system(size: 8))
                                            .foregroundStyle(SmartPawStyle.brown.opacity(0.48))
                                            .lineLimit(1)
                                    }
                                    .padding(8)
                                    .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(alignment: .topTrailing) {
                                        if isEditing {
                                            Button {
                                                viewModel.removeCatalogItem(item.id)
                                            } label: {
                                                Image(systemName: "trash.circle.fill")
                                                    .font(.system(size: 18))
                                                    .foregroundStyle(.red)
                                                    .background(.white, in: Circle())
                                            }
                                            .buttonStyle(.plain)
                                            .padding(4)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }

                MakeReplicaBottomNav(active: .constant(.classification), onCamera: onOpenCapture)
            }
        }
    }
}

private struct MakeAIClassificationBanner: View {
    let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
            Image(systemName: "sparkles").font(.system(size: 18)).foregroundStyle(.white)
                .frame(width: 40, height: 40).background(.white.opacity(0.25), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text("AI tagged new items").font(.system(size: 13, weight: .semibold))
                Text("Tap to review and confirm").font(.system(size: 11)).opacity(0.85)
            }
            Spacer()
            Image(systemName: "chevron.right")
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .padding(16)
        .background(SmartPawStyle.orange, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }
}

private struct MakeCategoryCard: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let category: ItemCategory
    let color: Color
    let count: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
            Image(systemName: categoryIcon).font(.system(size: 19)).foregroundStyle(.white)
                .frame(width: 44, height: 44).background(color, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(viewModel.language == .english ? category.englishName : category.rawValue).font(.system(size: 13, weight: .semibold)).foregroundStyle(SmartPawStyle.brown)
                Text("\(count) \(itemUnit)").font(.system(size: 11)).foregroundStyle(SmartPawStyle.brown.opacity(0.55))
            }
            Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var categoryIcon: String {
        switch category { case .books: "book.closed"; case .electronics: "ipad.and.iphone"; case .stationery: "pencil"; case .clothes: "tshirt"; case .toys: "gift"; case .trash: "trash"; case .tools: "wrench.and.screwdriver" }
    }

    private var itemUnit: String {
        viewModel.language == .english ? "items" : "件物品"
    }
}

private struct MakeRecentItem: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let item: DetectedItem
    let isEditing: Bool
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 7) {
            Image(systemName: "shippingbox")
                .font(.system(size: 22))
                .foregroundStyle(SmartPawStyle.orange)
                .frame(width: 48, height: 48)
                .background(SmartPawStyle.soft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            Text(viewModel.language == .english ? item.englishName : item.name).font(.system(size: 11, weight: .semibold)).foregroundStyle(SmartPawStyle.brown).lineLimit(1)
            Text(viewModel.language == .english ? item.englishCategory : item.category.rawValue).font(.system(size: 9)).foregroundStyle(.white).padding(.horizontal, 7).padding(.vertical, 3).background(SmartPawStyle.blue, in: Capsule())
            }
            .overlay(alignment: .topTrailing) {
                if isEditing {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? SmartPawStyle.orange : SmartPawStyle.brown.opacity(0.35))
                        .background(.white, in: Circle())
                        .padding(7)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct MakeCommunityScreen: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var selectedCase: CommunityCase?
    @State private var selectedDetailScreen: MakeCommunityDetailScreen?
    @State private var selectedFilter = "Recommended"

    private var visibleCases: [CommunityCase] {
        switch selectedFilter {
        case "Popular":
            return viewModel.communityCases.sorted { $0.likes > $1.likes }
        case "Tips":
            return viewModel.communityCases.filter { $0.style == .quickReset || $0.style == .professional }
        default:
            return viewModel.communityCases
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Community").font(.system(size: 24, weight: .semibold)).foregroundStyle(SmartPawStyle.brown)
                    Text("Small changes, shared spaces").font(.system(size: 12)).foregroundStyle(SmartPawStyle.brown.opacity(0.55))
                }
                .padding(.horizontal, 24)
                .padding(.top, 54)
                HStack(spacing: 8) {
                    ForEach(["Recommended", "Popular", "Tips"], id: \.self) { label in
                        Button { selectedFilter = label } label: {
                            MakePill(text: label, color: selectedFilter == label ? SmartPawStyle.orange : .white, foreground: selectedFilter == label ? .white : SmartPawStyle.brown)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)
                ForEach(visibleCases.prefix(4)) { item in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack { Text(viewModel.language == .english ? item.englishTitle : item.title).font(.system(size: 15, weight: .semibold)); Spacer(); Button { viewModel.toggleCommunityFavorite(item.id) } label: { Image(systemName: viewModel.favoriteCommunityCaseIDs.contains(item.id) ? "bookmark.fill" : "bookmark") }.buttonStyle(.plain).foregroundStyle(SmartPawStyle.brown.opacity(0.6)) }
                        Button { selectedCase = item } label: {
                            HStack(spacing: 8) {
                                MakeAssetImage(name: item.beforeAssetName ?? item.beforeImageName ?? "FigmaSpace")
                                MakeAssetImage(name: item.afterAssetName ?? item.afterImageName ?? "FigmaSpace")
                            }
                            .frame(height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        HStack { Text("@\(viewModel.language == .english ? item.englishAuthor : item.author)").font(.system(size: 11)).foregroundStyle(SmartPawStyle.brown.opacity(0.55)); Spacer(); Button { viewModel.toggleCommunityLike(item.id) } label: { Label("\(item.likes)", systemImage: viewModel.likedCommunityCaseIDs.contains(item.id) ? "heart.fill" : "heart") }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(SmartPawStyle.orange) }
                    }
                    .padding(14)
                    .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 122)
        }
        .fullScreenCover(item: $selectedCase) { item in
            CommunityFigmaCaseDetail(
                item: item,
                onDismiss: { selectedCase = nil },
                onShowComments: { selectedDetailScreen = .comments(item) },
                onShowPlan: { selectedDetailScreen = .plan(item) }
            )
            .environmentObject(viewModel)
        }
        .fullScreenCover(item: $selectedDetailScreen) { screen in
            switch screen {
            case let .comments(item):
                CommunityFigmaCommentsView(item: item, onDismiss: { selectedDetailScreen = nil })
                    .environmentObject(viewModel)
            case let .plan(item):
                CommunityFigmaPlanView(item: item, onStart: {
                    viewModel.replicate(item)
                    selectedDetailScreen = nil
                    selectedCase = nil
                })
                .environmentObject(viewModel)
            }
        }
    }
}

private enum MakeCommunityDetailScreen: Identifiable {
    case comments(CommunityCase)
    case plan(CommunityCase)

    var id: String {
        switch self {
        case let .comments(item): "comments-\(item.id.uuidString)"
        case let .plan(item): "plan-\(item.id.uuidString)"
        }
    }
}

private struct MakeMineScreen: View {
    @EnvironmentObject private var viewModel: AppViewModel
    let onRoute: (MakeReplicaRoute) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    SmartPawProfileAvatar(size: 96)
                        .padding(.bottom, 16)
                    Text("Sarah Chen").font(.system(size: 22, weight: .semibold)).foregroundStyle(SmartPawStyle.brown)
                        .padding(.bottom, 4)
                    Text("@sarah · Joined March 2026").font(.system(size: 13)).foregroundStyle(SmartPawStyle.brown.opacity(0.55))
                        .padding(.bottom, 12)
                    Text("Level 4 · Organization Master").font(.system(size: 11)).foregroundStyle(SmartPawStyle.brown).padding(.horizontal, 12).padding(.vertical, 6).background(SmartPawStyle.canvas, in: Capsule())
                }
                .padding(.top, 54).padding(.bottom, 24)
                HStack { MakeStat(value: "\(viewModel.catalogItems.count)", label: "Tracked items"); MakeStat(value: "\(viewModel.completedCount)", label: "Organized spaces"); MakeStat(value: "\(viewModel.achievements.count)", label: "Badges earned") }
                    .padding(.vertical, 18).overlay(alignment: .top) { Rectangle().fill(SmartPawStyle.soft).frame(height: 1) }.overlay(alignment: .bottom) { Rectangle().fill(SmartPawStyle.soft).frame(height: 1) }
                MakeSectionHeader(title: "Badges", action: "View all", onAction: { onRoute(.badges) })
                ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 12) { ForEach(Array(viewModel.achievements.prefix(7))) { achievement in MakeAchievement(icon: achievement.iconName, onTap: { onRoute(.badges) }) } }.padding(.horizontal, 24).padding(.vertical, 14) }
                VStack(spacing: 0) {
                    MakeMineRow(icon: "calendar", title: "My plans", subtitle: activePlansSubtitle, onTap: { onRoute(.plans) })
                    MakeMineRow(icon: "bookmark", title: "Saved posts", subtitle: "\(viewModel.favoriteCommunityCaseIDs.count)", onTap: { onRoute(.savedPosts) })
                    MakeMineRow(icon: "person.2", title: "Friends", subtitle: "Invite and share", onTap: { onRoute(.friends) })
                    MakeMineRow(icon: "gearshape", title: "Settings", subtitle: nil, onTap: { onRoute(.language) })
                    MakeMineRow(icon: "questionmark.circle", title: "Help & feedback", subtitle: nil, onTap: { onRoute(.help) })
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 122)
            }
        }
        .background(.white)
    }

    private var activePlansSubtitle: String {
        let count = viewModel.spaces.filter { $0.activePlan != nil }.count
        return viewModel.language == .english ? "\(count) active" : "\(count) 个进行中"
    }
}

struct SmartPawProfileAvatar: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [SmartPawStyle.canvas, SmartPawStyle.soft],
                        center: .center,
                        startRadius: 0,
                        endRadius: size / 2
                    )
                )
                .shadow(color: SmartPawStyle.orange.opacity(0.08), radius: 0, y: 0)
            SmartPawRaccoon()
                .frame(width: size * 0.79, height: size * 0.79)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityLabel("Profile avatar")
    }
}

private struct SmartPawRaccoon: View {
    private let dark = Color(red: 61 / 255, green: 44 / 255, blue: 34 / 255)
    private let head = Color(red: 168 / 255, green: 131 / 255, blue: 112 / 255)

    var body: some View {
        ZStack {
            Circle().fill(SmartPawStyle.brown).frame(width: 22, height: 22).offset(x: -24, y: -22)
            Circle().fill(SmartPawStyle.brown).frame(width: 22, height: 22).offset(x: 24, y: -22)
            Circle().fill(SmartPawStyle.orange.opacity(0.5)).frame(width: 11, height: 11).offset(x: -24, y: -22)
            Circle().fill(SmartPawStyle.orange.opacity(0.5)).frame(width: 11, height: 11).offset(x: 24, y: -22)

            Ellipse().fill(head).frame(width: 60, height: 58).offset(y: 3)
            Ellipse().fill(SmartPawStyle.canvas).frame(width: 51, height: 35).offset(y: 10)
            Ellipse().fill(dark).frame(width: 17, height: 20).offset(x: -15, y: 2)
            Ellipse().fill(dark).frame(width: 17, height: 20).offset(x: 15, y: 2)
            Circle().fill(.white).frame(width: 6, height: 6).offset(x: -15, y: 1)
            Circle().fill(.white).frame(width: 6, height: 6).offset(x: 15, y: 1)
            Circle().fill(dark).frame(width: 3.5, height: 3.5).offset(x: -15, y: 2)
            Circle().fill(dark).frame(width: 3.5, height: 3.5).offset(x: 15, y: 2)
            Circle().fill(SmartPawStyle.orange.opacity(0.35)).frame(width: 8, height: 8).offset(x: -24, y: 18)
            Circle().fill(SmartPawStyle.orange.opacity(0.35)).frame(width: 8, height: 8).offset(x: 24, y: 18)
            Ellipse().fill(dark).frame(width: 6, height: 4).offset(y: 18)
            RaccoonMouth().stroke(dark, style: StrokeStyle(lineWidth: 1.5, lineCap: .round)).frame(width: 12, height: 8).offset(y: 25)
        }
        .frame(width: 76, height: 76)
    }
}

private struct RaccoonMouth: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 1, y: rect.midY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - 1, y: rect.midY),
            control: CGPoint(x: rect.midX, y: rect.maxY)
        )
        return path
    }
}

private struct MakeStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value).font(.system(size: 22, weight: .semibold))
            Text(LocalizedStringKey(label)).font(.system(size: 11)).foregroundStyle(SmartPawStyle.brown.opacity(0.55))
        }
        .foregroundStyle(SmartPawStyle.brown)
        .frame(maxWidth: .infinity)
    }
}

private struct MakeAchievement: View {
    let icon: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Image(systemName: icon.isEmpty ? "star.fill" : icon)
                .font(.system(size: 22))
                .foregroundStyle(SmartPawStyle.orange)
                .frame(width: 56, height: 56)
                .background(SmartPawStyle.canvas, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct MakeMineRow: View {
    let icon: String
    let title: String
    let subtitle: String?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(SmartPawStyle.brown)
                    .frame(width: 40, height: 40)
                    .background(SmartPawStyle.canvas, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(title)).font(.system(size: 14, weight: .medium))
                    if let subtitle {
                        Text(LocalizedStringKey(subtitle)).font(.system(size: 11)).foregroundStyle(SmartPawStyle.brown.opacity(0.5))
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(SmartPawStyle.brown.opacity(0.35))
            }
            .foregroundStyle(SmartPawStyle.brown)
            .padding(.vertical, 14)
            .overlay(alignment: .bottom) {
                Rectangle().fill(SmartPawStyle.soft).frame(height: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct MakeSectionHeader: View {
    let title: String
    let action: String
    var isActionEnabled = true
    let onAction: () -> Void
    var body: some View {
        HStack {
            Text(LocalizedStringKey(title)).font(.system(size: 16, weight: .semibold))
            Spacer()
            if isActionEnabled {
                Button(action: onAction) {
                    Text(LocalizedStringKey(action))
                        .font(.system(size: 12))
                        .foregroundStyle(SmartPawStyle.orange)
                }
                .buttonStyle(.plain)
            } else {
                Text(LocalizedStringKey(action))
                    .font(.system(size: 12))
                    .foregroundStyle(SmartPawStyle.orange)
            }
        }
        .foregroundStyle(SmartPawStyle.brown)
        .padding(.horizontal, 24)
        .padding(.top, 26)
        .padding(.bottom, 12)
    }
}

private struct MakePill: View {
    let text: String
    let color: Color
    var foreground: Color = SmartPawStyle.brown
    var body: some View { Text(LocalizedStringKey(text)).font(.system(size: 11)).foregroundStyle(foreground).padding(.horizontal, 11).padding(.vertical, 6).background(color, in: Capsule()) }
}

private struct MakeAssetImage: View {
    let name: String
    var body: some View {
        GeometryReader { proxy in
            if let image = UIImage(named: name) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
            } else {
                SmartPawStyle.soft
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(SmartPawStyle.brown.opacity(0.25))
                    }
            }
        }
    }
}
