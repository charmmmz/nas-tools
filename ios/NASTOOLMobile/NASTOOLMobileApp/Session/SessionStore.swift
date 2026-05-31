import Foundation
import Observation

protocol CredentialStore: AnyObject {
    func load() throws -> StoredCredentials?
    func save(_ credentials: StoredCredentials) throws
    func delete() throws
}

struct StoredCredentials: Codable, Equatable, Sendable {
    let serverURL: URL
    let token: String
    let apiKey: String
    let username: String
}

@MainActor
@Observable
final class SessionStore {
    private let credentialStore: CredentialStore
    private let loginHandler: (URL, String, String) async throws -> LoginResponse

    private(set) var credentials: StoredCredentials?
    private(set) var isLoading = false
    var errorMessage: String?

    var isAuthenticated: Bool {
        credentials != nil
    }

    var apiClient: NastoolAPIClient? {
        guard let credentials else {
            return nil
        }
        return NastoolAPIClient(baseURL: credentials.serverURL, token: credentials.token)
    }

    init(
        credentialStore: CredentialStore = KeychainStore(),
        loginHandler: @escaping (URL, String, String) async throws -> LoginResponse = { serverURL, username, password in
            try await NastoolAPIClient(baseURL: serverURL).login(username: username, password: password)
        }
    ) {
        self.credentialStore = credentialStore
        self.loginHandler = loginHandler
    }

    func restore() throws {
        credentials = try credentialStore.load()
    }

    func login(serverURL: URL, username: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await loginHandler(serverURL, username, password)
            guard response.code == 0, response.success else {
                errorMessage = response.message ?? "Login failed."
                return
            }

            let credentials = StoredCredentials(
                serverURL: serverURL,
                token: response.data.token,
                apiKey: response.data.apiKey,
                username: response.data.user.username
            )
            try credentialStore.save(credentials)
            self.credentials = credentials
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func logout() throws {
        try credentialStore.delete()
        credentials = nil
        errorMessage = nil
    }
}
