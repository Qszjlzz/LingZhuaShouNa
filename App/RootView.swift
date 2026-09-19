import SwiftUI

/// The current Figma Make export is the single active application surface.
struct RootView: View {
    var body: some View {
        CurrentFigmaMakeWebView()
            .ignoresSafeArea()
    }
}
