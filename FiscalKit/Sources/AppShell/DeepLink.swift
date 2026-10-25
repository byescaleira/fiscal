import FeatureCore
import Foundation

enum DeepLink: Equatable {
    case section(AppSection)
    case route(Route, in: AppSection)

    init(url: URL) {
        guard url.scheme == "fiscal", let host = url.host() else {
            self = .section(.today)
            return
        }
        let path = url.pathComponents.dropFirst().first
        if let section = AppSection(rawValue: host) {
            self = .section(section)
        } else if let destination = Self.destination(host: host, path: path, url: url) {
            self = destination
        } else {
            self = .section(.today)
        }
    }

    private static func destination(host: String, path: String?, url: URL) -> DeepLink? {
        switch host {
        case "person": path.map { DeepLink.route(.person(slug: $0), in: .mine) }
        case "vote": path.map { DeepLink.route(.vote(id: $0), in: .votes) }
        case "compare": .route(.compare(slugs: slugs(in: url)), in: .search)
        case "races": .route(.races, in: .search)
        case "lens": .route(.lens, in: .today)
        case "artists": .route(.artists, in: .today)
        case "settings": .route(.settings, in: .today)
        default: nil
        }
    }

    private static func slugs(in url: URL) -> [String] {
        let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "slugs" }?.value
        return value?.split(separator: ",").map(String.init).filter { !$0.isEmpty } ?? []
    }

    static func handles(_ url: URL) -> Bool {
        url.scheme == "fiscal"
    }
}
