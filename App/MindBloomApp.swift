import SwiftUI
import SwiftData

@main
@MainActor
struct MindBloomApp: App {
    private let bootstrap = AppBootstrap()

    var body: some Scene {
        WindowGroup {
            RootView(storeWarning: bootstrap.storeWarning)
                .environment(bootstrap.navigation)
        }
        .modelContainer(bootstrap.container)
    }
}
