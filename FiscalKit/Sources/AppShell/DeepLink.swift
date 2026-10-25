import FeatureCore
import Foundation

enum DeepLink: Equatable {
    case section(AppSection)
    case route(Route, in: AppSection)

    init(url: URL) {
        guard url.scheme == "fiscal" else {
            self = .section(.today)
            return
        }
        switch url.host() {
        case "races":
            self = .route(.races, in: .today)
        case "settings":
            self = .section(.settings)
        default:
            self = .section(.today)
        }
    }

    static func handles(_ url: URL) -> Bool {
        url.scheme == "fiscal"
    }
}
