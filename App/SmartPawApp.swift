import SwiftUI

@main
struct SmartPawApp: App {
    @StateObject private var viewModel = AppViewModel(dependencies: .live)

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(viewModel)
        }
    }
}
