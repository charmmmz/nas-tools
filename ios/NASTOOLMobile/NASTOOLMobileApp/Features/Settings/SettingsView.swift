import SwiftUI

struct SettingsView: View {
    @Environment(SessionStore.self) private var sessionStore

    var body: some View {
        Form {
            if let credentials = sessionStore.credentials {
                Section("Account") {
                    LabeledContent("Server", value: credentials.serverURL.absoluteString)
                    LabeledContent("Username", value: credentials.username)
                }
            }

            Section {
                Button("Log Out", role: .destructive) {
                    try? sessionStore.logout()
                }
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    let store = VolatileCredentialStore()
    let sessionStore = SessionStore(credentialStore: store)
    try? store.save(
        StoredCredentials(
            serverURL: URL(string: "https://nas.example.com")!,
            token: "token",
            apiKey: "api-key",
            username: "admin"
        )
    )
    try? sessionStore.restore()

    return NavigationStack {
        SettingsView()
            .environment(sessionStore)
    }
}
