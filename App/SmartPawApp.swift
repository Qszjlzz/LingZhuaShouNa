import SwiftUI

@main
struct SmartPawApp: App {
    @StateObject private var viewModel = AppViewModel(dependencies: .live)

    init() {
        #if DEBUG
        ImageGenerationManager.shared.importDebugConfigurationIfRequested()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(viewModel)
        }
    }
}
