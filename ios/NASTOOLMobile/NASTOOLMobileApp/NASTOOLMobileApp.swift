import SwiftUI

@main
struct NASTOOLMobileApp: App {
    @State private var sessionStore = SessionStoreFactory.make()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(sessionStore)
                .task {
                    try? sessionStore.restore()
                }
        }
    }
}
