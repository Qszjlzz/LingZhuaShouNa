import SwiftUI

struct RootView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var didRunLaunchAutomation = false
    @State private var showsSpaceBottomBar = true
    @State private var showsLaunchIntro = true

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.97, green: 0.95, blue: 0.91, alpha: 1)
        appearance.shadowColor = UIColor(red: 0.22, green: 0.18, blue: 0.15, alpha: 0.14)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        ZStack {
            #if DEBUG
            if CommandLine.arguments.contains("-SmartPawShowFirstCapture") {
                FigmaFirstCaptureView()
            } else if CommandLine.arguments.contains("-SmartPawShowCompletion") {
                CompletionView()
            } else if CommandLine.arguments.contains("-SmartPawShowExecution"), let plan = viewModel.activePlan {
                ExecutionView(plan: plan)
            } else if CommandLine.arguments.contains("-SmartPawShowCommunityDetail"), let item = viewModel.communityCases.first {
                CommunityFigmaCaseDetail(item: item, onDismiss: {}, onShowComments: {}, onShowPlan: {})
            } else if CommandLine.arguments.contains("-SmartPawShowCommunityComments"), let item = viewModel.communityCases.first {
                CommunityFigmaCommentsView(item: item, onDismiss: {})
            } else if CommandLine.arguments.contains("-SmartPawShowCommunityPlan"), let item = viewModel.communityCases.first {
                CommunityFigmaPlanView(item: item, onStart: {})
            } else if CommandLine.arguments.contains("-SmartPawShowProfilePlans") {
                ProfileFigmaPlansView(onDismiss: {})
                    .environmentObject(viewModel)
            } else if CommandLine.arguments.contains("-SmartPawShowProfileBadges") {
                ProfileFigmaBadgesView(onDismiss: {}) { _ in }
            } else if CommandLine.arguments.contains("-SmartPawShowProfileBadgeDetail") {
                ProfileFigmaBadgeDetailView(badge: ProfileBadge.samples[0], onDismiss: {})
            } else if CommandLine.arguments.contains("-SmartPawShowProfileLockedBadgeDetail") {
                ProfileFigmaBadgeDetailView(badge: ProfileBadge.samples[7], onDismiss: {})
            } else if CommandLine.arguments.contains("-SmartPawShowProfileSchedule") {
                ProfileFigmaScheduleView(onDismiss: {})
                    .environmentObject(viewModel)
            } else {
                appSurface
            }
            #else
            appSurface
            #endif

            if (showsLaunchIntro && !isAutomatedScreenshotRoute) || shouldForceLaunchIntro {
                AppLaunchIntro {
                    showsLaunchIntro = false
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .tint(SmartPawStyle.orange)
        .font(FigmaFont.regular(14))
        .alert("灵爪收纳", isPresented: Binding(
            get: { viewModel.message != nil },
            set: { if !$0 { viewModel.clearMessage() } }
        )) {
            Button("知道了") { viewModel.clearMessage() }
        } message: {
            Text(viewModel.message ?? "")
        }
        #if DEBUG
        .task {
            guard !didRunLaunchAutomation else { return }
            didRunLaunchAutomation = true
            await viewModel.runRealVisionSampleScanForScreenshotIfRequested()
        }
        #endif
    }

    private var shouldForceLaunchIntro: Bool {
        #if DEBUG
        CommandLine.arguments.contains("-SmartPawKeepLaunchIntro")
        #else
        false
        #endif
    }

    private var isAutomatedScreenshotRoute: Bool {
        #if DEBUG
        let arguments = CommandLine.arguments
        return arguments.contains(where: { $0.hasPrefix("-SmartPawShow") })
            || arguments.contains(where: { $0.hasPrefix("-SmartPawAuto") })
        #else
        return false
        #endif
    }

    private var appSurface: some View {
        Group {
            switch viewModel.selectedTab {
            case .space: SpaceView(showsBottomNavigation: $showsSpaceBottomBar)
            case .catalog: CatalogView()
            case .capture: CaptureView()
            case .community: CommunityView()
            case .profile: ProfileView()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if viewModel.selectedTab != .capture
                && (viewModel.selectedTab != .space || showsSpaceBottomBar) {
                FigmaBottomBar(selection: $viewModel.selectedTab)
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

private struct AppLaunchIntro: View {
    let onContinue: () -> Void
    @State private var hasScheduledAdvance = false

    var body: some View {
        Image("LaunchCover")
            .resizable()
            .scaledToFill()
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture(perform: onContinue)
            .accessibilityLabel("灵爪收纳")
            .accessibilityAddTraits(.isButton)
        .task {
            guard !hasScheduledAdvance else { return }
            hasScheduledAdvance = true
            #if DEBUG
            guard !CommandLine.arguments.contains("-SmartPawKeepLaunchIntro") else { return }
            #endif
            try? await Task.sleep(for: .seconds(1.2))
            if !Task.isCancelled { onContinue() }
        }
    }
}

struct ScreenBackground<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        ZStack {
            SmartPawStyle.canvas.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        Image(systemName: "pawprint.fill")
                            .font(.headline.weight(.black))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(SmartPawStyle.orange, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(title)
                                .font(.headline.weight(.black))
                                .foregroundStyle(SmartPawStyle.brown)
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(SmartPawStyle.brown.opacity(0.72))
                        }
                        Spacer()
                    }
                    .padding(.top, 2)

                    content
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .toolbarBackground(SmartPawStyle.canvas, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

struct CompletionView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        ZStack {
            SmartPawStyle.canvas.ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer(minLength: 42)
                VStack(spacing: 18) {
                    Image("FigmaCompletion")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 116, height: 116)
                        .clipShape(Circle())
                    Text("新徽章")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22)
                        .frame(height: 34)
                        .background(SmartPawStyle.orange, in: Capsule())
                    Text("整洁的浣熊")
                        .font(.system(size: 29, weight: .regular))
                        .foregroundStyle(Color(red: 0.37, green: 0.25, blue: 0.18))
                    Text("你完成了你的第一个区域——保持连胜！")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(Color(red: 0.68, green: 0.59, blue: 0.52))
                        .multilineTextAlignment(.center)
                    HStack(spacing: 14) {
                        CompletionMetric(value: "+45", label: "物品")
                        CompletionMetric(value: "33:42", label: "分钟")
                        CompletionMetric(value: "+50", label: "XP")
                    }
                    .padding(.top, 16)
                    Button {
                        viewModel.selectedTab = .space
                        viewModel.showMessage("已返回空间首页。")
                    } label: {
                        Text("继续")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 58)
                            .background(SmartPawStyle.orange, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 12)
                }
                .padding(.horizontal, 28)
                .padding(.top, 38)
                .padding(.bottom, 34)
                .background(.white, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
                .padding(.horizontal, 24)
                Spacer(minLength: 42)
            }
        }
    }
}

private struct CompletionMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(SmartPawStyle.orange)
            Text(label)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color(red: 0.68, green: 0.59, blue: 0.52))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 76)
        .background(SmartPawStyle.canvas, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct FigmaFirstCaptureView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var isCapturing = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if let sampleImage {
                    Image(uiImage: sampleImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    SmartPawStyle.canvas
                }
            }
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.08))

            VStack(spacing: 0) {
                HStack {
                    HStack(spacing: 10) {
                        Image(systemName: "camera.fill")
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(SmartPawStyle.orange, in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text("拍摄完成后的照片")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(SmartPawStyle.brown)
                            Text("让我们记录你的整理成果吧")
                                .font(.caption2)
                                .foregroundStyle(SmartPawStyle.brown.opacity(0.65))
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(width: 226, height: 70, alignment: .leading)
                    .background(.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 52)

                Spacer()

                HStack {
                    Button {
                        viewModel.selectedTab = .space
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(SmartPawStyle.brown)
                            .frame(width: 48, height: 48)
                            .background(.white.opacity(0.92), in: Circle())
                    }
                    .accessibilityLabel("关闭拍摄")
                    Spacer()
                    Button {
                        isCapturing = true
                        Task {
                            await viewModel.scanBundledSample(assetName: AppSampleAssets.clutteredStudy)
                            isCapturing = false
                            viewModel.selectedTab = .catalog
                        }
                    } label: {
                        Circle()
                            .fill(SmartPawStyle.orange)
                            .frame(width: 76, height: 76)
                            .overlay(Circle().stroke(.white, lineWidth: 5))
                            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                    }
                    .accessibilityLabel("拍摄并识别")
                    .disabled(isCapturing)
                    Spacer()
                    Button {
                        viewModel.selectedTab = .catalog
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 52, height: 52)
                            .background(SmartPawStyle.orange, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .accessibilityLabel("完成拍摄")
                }
                .padding(.horizontal, 26)
                .padding(.bottom, 28)
            }
        }
    }

    private var sampleImage: UIImage? {
        guard let path = Bundle.main.path(forResource: "external-cluttered-study-pexels", ofType: "jpg") else { return nil }
        return UIImage(contentsOfFile: path)
    }
}
