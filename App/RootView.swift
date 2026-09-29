import SwiftUI

extension Notification.Name {
    static let smartPawWebReady = Notification.Name("smartpaw.webReady")
}

/// 启动封面：点开 App 第一眼到网页真正就绪之间，看到的都是这张「凌乱有解法」。
/// 网页加载完成（didFinish）后淡出；事件万一丢失，5 秒后强制淡出兜底。
struct RootView: View {
    @State private var showSplash = true

    var body: some View {
        ZStack {
            CurrentFigmaMakeWebView()
                .ignoresSafeArea()
            if showSplash {
                GeometryReader { geo in
                    Image("LaunchCover")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
                .ignoresSafeArea()
                .transition(.opacity)
                .onReceive(NotificationCenter.default.publisher(for: .smartPawWebReady)) { _ in
                    withAnimation(.easeOut(duration: 0.35)) { showSplash = false }
                }
                .task {
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    withAnimation(.easeOut(duration: 0.35)) { showSplash = false }
                }
            }
        }
    }
}
