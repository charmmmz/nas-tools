import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case downloads
    case search
    case subscriptions
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .downloads:
            "Downloads"
        case .search:
            "Search"
        case .subscriptions:
            "Subscriptions"
        case .settings:
            "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .downloads:
            "arrow.down.circle"
        case .search:
            "magnifyingglass"
        case .subscriptions:
            "bookmark"
        case .settings:
            "gearshape"
        }
    }
}

struct AppRootView: View {
    @Environment(SessionStore.self) private var sessionStore
    @State private var selectedTab: AppTab = .downloads

    var body: some View {
        Group {
            if sessionStore.isAuthenticated {
                TabView(selection: $selectedTab) {
                    ForEach(AppTab.allCases) { tab in
                        NavigationStack {
                            AppTabContentView(tab: tab)
                        }
                        .tabItem {
                            Label(tab.title, systemImage: tab.systemImage)
                        }
                        .tag(tab)
                    }
                }
            } else {
                LoginView()
            }
        }
    }
}

private struct AppTabContentView: View {
    @Environment(SessionStore.self) private var sessionStore

    let tab: AppTab

    @ViewBuilder
    var body: some View {
        switch tab {
        case .downloads:
            if let apiClient = sessionStore.apiClient {
                DownloadsView(api: apiClient)
            } else {
                ContentUnavailableView(tab.title, systemImage: tab.systemImage)
                    .navigationTitle(tab.title)
            }
        case .search:
            if let apiClient = sessionStore.apiClient {
                SearchView(api: apiClient, imageBaseURL: apiClient.baseURL)
            } else {
                ContentUnavailableView(tab.title, systemImage: tab.systemImage)
                    .navigationTitle(tab.title)
            }
        case .subscriptions:
            if let apiClient = sessionStore.apiClient {
                SubscriptionsView(api: apiClient)
            } else {
                ContentUnavailableView(tab.title, systemImage: tab.systemImage)
                    .navigationTitle(tab.title)
            }
        case .settings:
            SettingsView()
        }
    }
}

#Preview {
    AppRootView()
        .environment(SessionStore(credentialStore: VolatileCredentialStore()))
}
