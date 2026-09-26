import SwiftUI

/// The current Figma Make export is the single active application surface.
struct RootView: View {
    /// 网页首次加载完成前显示品牌占位，避免冷启动时整屏死白。
    @State private var webReady = false

    var body: some View {
        ZStack {
            Color(red: 237 / 255, green: 229 / 255, blue: 218 / 255).ignoresSafeArea()
            CurrentFigmaMakeWebView(isReady: $webReady).ignoresSafeArea()
            if !webReady {
                VStack(spacing: 14) {
                    Text("🦝").font(.system(size: 60))
                    Text("灵爪收纳").font(.system(size: 22, weight: .bold))
                        .foregroundColor(Color(red: 0.42, green: 0.32, blue: 0.26))
                    Text("正在准备界面…").font(.system(size: 13))
                        .foregroundColor(Color(red: 0.42, green: 0.32, blue: 0.26).opacity(0.6))
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: webReady)
    }
}
