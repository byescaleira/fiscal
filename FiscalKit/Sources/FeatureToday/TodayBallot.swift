import FiscalDomain
import Foundation

public enum TodayBallot: Hashable, Sendable {
    case yes, no, abstention, absent
    case other(String)

    public init(_ text: String) {
        switch text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil) {
        case "sim": self = .yes
        case "nao": self = .no
        case "abstencao": self = .abstention
        case "ausente": self = .absent
        default: self = .other(text)
        }
    }

    public var title: String {
        switch self {
        case .yes: String(appLocalized: "Yes")
        case .no: String(appLocalized: "No")
        case .abstention: String(appLocalized: "Abstained")
        case .absent: String(appLocalized: "Absent")
        case .other(let text): text
        }
    }

    public var symbol: String {
        switch self {
        case .yes: "checkmark"
        case .no: "xmark"
        case .abstention: "minus"
        case .absent: "circle.dashed"
        case .other: "ellipsis"
        }
    }
}
