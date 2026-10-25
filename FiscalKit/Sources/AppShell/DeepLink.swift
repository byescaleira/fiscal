import FeatureCore
import Foundation

enum DeepLink: Equatable {
    case section(AppSection)
    case route(Route, in: AppSection)

    init(url: URL) {
        guard url.scheme == "fiscal" else {
            self = .section(.home)
            return
        }
        let path = url.pathComponents.dropFirst().first
        switch url.host() {
        case "items":
            self = .route(.item(id: path == "new" ? nil : path), in: .home)
        case "settings":
            self = .section(.settings)
        default:
            self = .section(.home)
        }
    }

    static func handles(_ url: URL) -> Bool {
        url.scheme == "fiscal"
    }
}
