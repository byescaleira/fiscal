import FiscalDomain
import Foundation

public enum FiscalEvents: Hashable, Sendable {
    case launch
    case dataLoaded
    case networkError(status: Int)
    case offlinePack(files: Int)
    case alertReceived
    case deepLink(DeepLinkKind)

    public enum DeepLinkKind: String, CaseIterable, Sendable {
        case section
        case person
        case vote
        case expenses
        case compare
        case races
        case race
        case place
        case highlight
        case awaiting
        case memory
        case election
        case period
        case study
        case support
        case artists
        case settings
        case unknown
    }

    public var category: LogCategory {
        switch self {
        case .launch: .app
        case .dataLoaded, .networkError: "data"
        case .offlinePack: "offline"
        case .alertReceived: "alerts"
        case .deepLink: "navigation"
        }
    }

    public var level: LogLevel {
        switch self {
        case .dataLoaded: .debug
        case .launch, .offlinePack, .alertReceived, .deepLink: .info
        case .networkError: .error
        }
    }

    public var message: LogMessage {
        switch self {
        case .launch: "App launched"
        case .dataLoaded: "Public data loaded"
        case .networkError(let status): "Network error, HTTP status \(code: status)"
        case .offlinePack(let files): "Offline pack refreshed, \(count: files) files"
        case .alertReceived: "Highlight alert received"
        case .deepLink(let kind): "Deep link opened: \(kind)"
        }
    }

    public func log(to log: EventLog = .shared) {
        log.log(level, message, category: category)
    }

    public static func networkError(for error: any Error) -> FiscalEvents? {
        guard case .rejected(let status) = error as? PublicDataError else { return nil }
        return .networkError(status: status)
    }
}
