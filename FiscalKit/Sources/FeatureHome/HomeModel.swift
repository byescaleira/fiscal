import FeatureCore
import FiscalDomain
import Foundation
import Observation

@MainActor @Observable
public final class HomeModel {
    public private(set) var items: [Item] = []
    public private(set) var hasLoaded = false
    public var error: FiscalError?
    @ObservationIgnored private let repositories: Repositories

    public init(repositories: Repositories) {
        self.repositories = repositories
    }

    public var isEmpty: Bool { hasLoaded && items.isEmpty }

    public var count: Int { items.count }

    public var countText: String { count.formatted(.number.locale(.app)) }

    public var latestText: String {
        guard let latest = items.first else { return String(appLocalized: "Nothing yet") }
        let date = latest.createdAt.formatted(
            Date.FormatStyle(date: .abbreviated, time: .omitted, locale: .app))
        return String(appLocalized: "Last added on \(date)")
    }

    public func detail(for item: Item) -> String {
        item.createdAt.formatted(
            Date.FormatStyle(date: .abbreviated, time: .shortened, locale: .app))
    }

    public func load() async {
        do {
            items = try await repositories.items.items()
            hasLoaded = true
        } catch is CancellationError {} catch {
            self.error = error as? FiscalError ?? .onFetch
        }
    }
}
