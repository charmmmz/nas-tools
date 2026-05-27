import Foundation

enum SessionStoreFactory {
    @MainActor
    static func make() -> SessionStore {
        if ProcessInfo.processInfo.environment["NASTOOL_UI_TESTING"] == "1" {
            return SessionStore(credentialStore: VolatileCredentialStore())
        }
        return SessionStore()
    }
}

final class VolatileCredentialStore: CredentialStore {
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
