import Foundation
import Observation

protocol HomeAPI: Sendable {
    func fetchHomeFeed(
        group: HomeFeedGroup,
        filter: HomeFeedFilter,
        region: String?,
        page: Int
    ) async throws -> HomeFeedResponse
}

extension NastoolAPIClient: HomeAPI {}

protocol HomeDetailAPI: Sendable {
    func searchKeyword(
        _ keyword: String,
        quickMode: Bool,
        tmdbID: String?,
        mediaType: String?
    ) async throws -> NastoolCommandResponse
    func addSubscription(_ request: AddSubscriptionRequest) async throws -> NastoolCommandResponse
}

extension NastoolAPIClient: HomeDetailAPI {}

enum HomeRegionSelection: Equatable, Hashable {
    case automatic
    case region(String)

    var storedRegionCode: String? {
        switch self {
        case .automatic:
            nil
        case .region(let code):
            Self.normalizedRegionCode(code)
        }
    }

    static func normalizedRegionCode(_ code: String?) -> String? {
        guard let code else {
            return nil
        }

        let normalized = code
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        guard normalized.count == 2, normalized.allSatisfy(\.isLetter) else {
            return nil
        }
        return normalized
    }
}

protocol HomeRegionStorage {
    func loadRegionCode() -> String?
    func saveRegionCode(_ regionCode: String?)
}

struct UserDefaultsHomeRegionStorage: HomeRegionStorage {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "home.region.override") {
        self.defaults = defaults
        self.key = key
    }

    func loadRegionCode() -> String? {
        HomeRegionSelection.normalizedRegionCode(defaults.string(forKey: key))
    }

    func saveRegionCode(_ regionCode: String?) {
        if let regionCode = HomeRegionSelection.normalizedRegionCode(regionCode) {
            defaults.set(regionCode, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}

@MainActor
@Observable
final class HomeStore {
    private let api: HomeAPI
    private let localeRegionProvider: () -> String?
    private let regionStorage: HomeRegionStorage
    private var loadGeneration = 0

    var selectedGroup: HomeFeedGroup = .trending
    var selectedFilter: HomeFeedFilter = .today
    var regionSelection: HomeRegionSelection {
        didSet {
            regionStorage.saveRegionCode(regionSelection.storedRegionCode)
        }
    }

    private(set) var items: [HomePosterItem] = []
    private(set) var page = 0
    private(set) var hasMore = false
    private(set) var isLoading = false
    var errorMessage: String?

    init(
        api: HomeAPI,
        localeRegionProvider: @escaping () -> String? = {
            Locale.autoupdatingCurrent.region?.identifier
        },
        regionStorage: HomeRegionStorage = UserDefaultsHomeRegionStorage()
    ) {
        self.api = api
        self.localeRegionProvider = localeRegionProvider
        self.regionStorage = regionStorage

        if let storedRegionCode = regionStorage.loadRegionCode() {
            regionSelection = .region(storedRegionCode)
        } else {
            regionSelection = .automatic
        }
    }

    var filters: [HomeFeedFilter] {
        switch selectedGroup {
        case .trending:
            [.today, .week]
        case .popular:
            [.streaming, .theaters]
        }
    }

    var effectiveRegion: String? {
        switch regionSelection {
        case .automatic:
            HomeRegionSelection.normalizedRegionCode(localeRegionProvider())
        case .region(let code):
            HomeRegionSelection.normalizedRegionCode(code)
        }
    }

    var requestRegion: String? {
        switch selectedGroup {
        case .trending:
            nil
        case .popular:
            effectiveRegion
        }
    }

    func select(group: HomeFeedGroup) {
        selectedGroup = group
        selectedFilter = defaultFilter(for: group)
    }

    func select(filter: HomeFeedFilter) {
        guard filters.contains(filter) else {
            return
        }
        selectedFilter = filter
    }

    func loadInitial() async {
        loadGeneration += 1
        await load(page: 1, replacingExistingItems: true, generation: loadGeneration)
    }

    func loadMore() async {
        guard hasMore, !isLoading else {
            return
        }
        await load(page: page + 1, replacingExistingItems: false, generation: loadGeneration)
    }

    private func load(page: Int, replacingExistingItems: Bool, generation: Int) async {
        isLoading = true
        defer {
            if generation == loadGeneration {
                isLoading = false
            }
        }

        do {
            let response = try await api.fetchHomeFeed(
                group: selectedGroup,
                filter: selectedFilter,
                region: requestRegion,
                page: page
            )

            guard generation == loadGeneration else {
                return
            }

            guard response.code == 0 else {
                errorMessage = response.message ?? "Home feed failed."
                return
            }

            self.page = response.data.page
            hasMore = response.data.hasMore
            if replacingExistingItems {
                items = response.data.items
            } else {
                items.append(contentsOf: response.data.items)
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func defaultFilter(for group: HomeFeedGroup) -> HomeFeedFilter {
        switch group {
        case .trending:
            .today
        case .popular:
            .streaming
        }
    }
}
