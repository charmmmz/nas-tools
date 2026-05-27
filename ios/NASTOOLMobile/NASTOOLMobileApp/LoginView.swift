import SwiftUI

struct LoginView: View {
    @Environment(SessionStore.self) private var sessionStore

    @State private var serverURL = ""
    @State private var username = ""
    @State private var password = ""
    @State private var validationMessage: String?

    private var canSubmit: Bool {
        !serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Server URL", text: $serverURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()

                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    SecureField("Password", text: $password)
                }

                Section {
                    Button(action: signIn) {
                        if sessionStore.isLoading {
                            ProgressView()
                        } else {
                            Label("Sign In", systemImage: "person.crop.circle.badge.checkmark")
                        }
                    }
                    .disabled(!canSubmit || sessionStore.isLoading)
                }

                if let message = validationMessage ?? sessionStore.errorMessage {
                    Section {
                        Text(message)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("NASTOOL")
        }
    }

    private func signIn() {
        validationMessage = nil

        guard let url = normalizedServerURL() else {
            validationMessage = "Enter a valid server URL."
            return
        }

        Task {
            await sessionStore.login(
                serverURL: url,
                username: username.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )
        }
    }

    private func normalizedServerURL() -> URL? {
        var value = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            return nil
        }

        let lowercased = value.lowercased()
        if !lowercased.hasPrefix("http://") && !lowercased.hasPrefix("https://") {
            value = "https://\(value)"
        }

        guard let url = URL(string: value), url.host != nil else {
            return nil
        }
        return url
    }
}

#Preview {
    LoginView()
        .environment(SessionStore(credentialStore: VolatileCredentialStore()))
}
