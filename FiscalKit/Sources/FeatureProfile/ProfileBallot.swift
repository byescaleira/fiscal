import FiscalDomain
import Foundation

public enum ProfileBallot: Hashable, Sendable {
    case yes, no, abstention, absent
    case other(String)

    public static let tallied: [ProfileBallot] = [.yes, .no, .abstention, .absent]

    public init(_ text: String) {
        let key = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        switch key {
        case "sim", "yes": self = .yes
        case "nao", "no": self = .no
        case "abstencao", "abstention": self = .abstention
        case "ausente", "absent", "": self = .absent
        default: self = .other(text)
        }
    }

    public var title: String {
        switch self {
        case .yes: String(appLocalized: "Yes")
        case .no: String(appLocalized: "No")
        case .abstention: String(appLocalized: "Abstention")
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
