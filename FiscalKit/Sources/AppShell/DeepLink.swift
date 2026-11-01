import FeatureCore
import Foundation

enum DeepLink: Equatable {
    case section(AppSection)
    case route(Route, in: AppSection)

    static let siteHost = "fiscal.byescaleira.com"
    static let siteKeys = ["person", "vote", "expenses", "compare", "place", "race", "highlight"]

    init(url: URL) {
        if Self.isSite(url) {
            self = Self.site(url) ?? .section(.today)
            return
        }
        guard url.scheme == "fiscal", let host = url.host() else {
            self = .section(.today)
            return
        }
        let path = url.pathComponents.dropFirst().first
        if let section = Self.section(host: host) {
            self = .section(section)
        } else if let destination = Self.destination(host: host, path: path, url: url) {
            self = destination
        } else {
            self = .section(.today)
        }
    }

    private static func destination(host: String, path: String?, url: URL) -> DeepLink? {
        switch host {
        case "person": path.map { DeepLink.route(.person(slug: $0), in: .following) }
        case "vote": path.map { DeepLink.route(.vote(id: $0), in: .votes) }
        case "highlight": path.map { DeepLink.route(.highlight(id: $0), in: .today) }
        case "expenses":
            path.map { DeepLink.route(.expenses(slug: $0, year: year(in: url)), in: .money) }
        case "compare": .route(.compare(slugs: slugs(in: url)), in: .search)
        case "races": .route(.races, in: .search)
        case "race": path.map { DeepLink.route(.race(id: $0), in: .search) }
        case "awaiting": .route(.awaiting, in: .search)
        case "memory": .route(.memory, in: .search)
        case "election":
            path.flatMap(Int.init).map { DeepLink.route(.pastElection(year: $0), in: .search) }
        case "period": path.map { DeepLink.route(.period(id: $0), in: .search) }
        case "study": path.map { DeepLink.route(.studyGuide(id: $0), in: .search) }
        case "lens": .route(.lens, in: .today)
        case "artists": .route(.artists, in: .today)
        case "settings": .route(.settings, in: .today)
        default: nil
        }
    }

    private static func isSite(_ url: URL) -> Bool {
        url.scheme == "https" && url.host()?.lowercased() == siteHost
    }

    private static func siteItem(in url: URL) -> (key: String, value: String)? {
        guard url.path().isEmpty || url.path() == "/" else { return nil }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        for item in items where siteKeys.contains(item.name) {
            guard let value = item.value, !value.isEmpty, !value.contains("/"),
                !value.contains(".."), !value.contains("\\")
            else { return nil }
            return (item.name, value)
        }
        return nil
    }

    private static func site(_ url: URL) -> DeepLink? {
        guard let item = siteItem(in: url) else { return nil }
        let value = item.value
        return switch item.key {
        case "person": .route(.person(slug: value), in: .following)
        case "vote": .route(.vote(id: value), in: .votes)
        case "expenses": expenses(value)
        case "compare": .route(.compare(slugs: slugs(value)), in: .search)
        case "place": .route(.share(.representatives(uf: value.lowercased())), in: .following)
        case "race": .route(.race(id: value), in: .search)
        case "highlight": .route(.share(.highlight(id: value)), in: .today)
        default: nil
        }
    }

    private static func expenses(_ value: String) -> DeepLink {
        let parts = value.split(separator: "-")
        if parts.count > 1, let last = parts.last, let year = Int(last), last.count == 4 {
            let slug = parts.dropLast().joined(separator: "-")
            return .route(.expenses(slug: slug, year: year), in: .money)
        }
        let year = Calendar.current.component(.year, from: .now)
        return .route(.expenses(slug: value, year: year), in: .money)
    }

    private static func section(host: String) -> AppSection? {
        host == "mine" ? .following : AppSection(rawValue: host)
    }

    private static func slugs(in url: URL) -> [String] {
        let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "slugs" }?.value
        return slugs(value ?? "")
    }

    private static func slugs(_ value: String) -> [String] {
        value.split(separator: ",").map(String.init).filter { !$0.isEmpty }
    }

    private static func year(in url: URL) -> Int {
        let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "year" }?.value
        return value.flatMap(Int.init) ?? Calendar.current.component(.year, from: .now)
    }

    static func kind(of url: URL) -> FiscalEvents.DeepLinkKind {
        if isSite(url) {
            guard let item = siteItem(in: url), site(url) != nil else { return .unknown }
            return FiscalEvents.DeepLinkKind(rawValue: item.key) ?? .unknown
        }
        guard url.scheme == "fiscal", let host = url.host() else { return .unknown }
        if section(host: host) != nil { return .section }
        guard let kind = FiscalEvents.DeepLinkKind(rawValue: host), kind != .section else {
            return .unknown
        }
        return DeepLink(url: url) == .section(.today) ? .unknown : kind
    }

    static func handles(_ url: URL) -> Bool {
        url.scheme == "fiscal" || isSite(url)
    }
}
