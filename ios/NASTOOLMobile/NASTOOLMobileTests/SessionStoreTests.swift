import XCTest
@testable import NASTOOLMobile

@MainActor
final class SessionStoreTests: XCTestCase {
    func testRestoreLoadsSavedCredentials() throws {
        let credentials = StoredCredentials(
            serverURL: try XCTUnwrap(URL(string: "https://nas.example.com")),
            token: "jwt-token",
            apiKey: "api-key",
            username: "admin"
        )
        let credentialStore = TestCredentialStore()
        try credentialStore.save(credentials)
        let sessionStore = SessionStore(credentialStore: credentialStore)

        try sessionStore.restore()

        XCTAssertTrue(sessionStore.isAuthenticated)
        XCTAssertEqual(sessionStore.credentials, credentials)
        XCTAssertEqual(sessionStore.apiClient?.baseURL, credentials.serverURL)
    }

    func testLogoutClearsStoredCredentials() throws {
        let credentials = StoredCredentials(
            serverURL: try XCTUnwrap(URL(string: "https://nas.example.com")),
            token: "jwt-token",
            apiKey: "api-key",
            username: "admin"
        )
        let credentialStore = TestCredentialStore()
        try credentialStore.save(credentials)
        let sessionStore = SessionStore(credentialStore: credentialStore)
        try sessionStore.restore()

        try sessionStore.logout()

        XCTAssertFalse(sessionStore.isAuthenticated)
        XCTAssertNil(sessionStore.credentials)
        XCTAssertNil(try credentialStore.load())
    }
}

private final class TestCredentialStore: CredentialStore {
    private var credentials: StoredCredentials?

    func load() throws -> StoredCredentials? {
        credentials
    }

    func save(_ credentials: StoredCredentials) throws {
        self.credentials = credentials
    }

    func delete() throws {
        credentials = nil
    }
}
