import Foundation

public struct HistoryRef: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let url: URL?

    public init(id: String, name: String, url: URL?) {
        self.id = id
        self.name = name
        self.url = url
    }
}

public struct PastCandidate: Codable, Hashable, Identifiable, Sendable {
    public let number: String
    public let name: String
    public let ballotName: String
    public let party: String
    public let coalition: String?
    public let members: String?
    public let votes: Int
    public let annulled: Int?
    public let share: Double
    public let result: String
    public let elected: Bool
    public let advanced: Bool

    public var id: String { "\(number)-\(name)" }
}

public struct PastStateTally: Codable, Hashable, Identifiable, Sendable {
    public let uf: String
    public let name: String
    public let valid: Int
    public let winner: String
    public let share: Double
    public let votes: [String: Int]

    public var id: String { uf }
}

public struct PastRound: Codable, Hashable, Identifiable, Sendable {
    public let round: Int
    public let date: String
    public let electorate: Int?
    public let turnout: Int?
    public let abstentions: Int?
    public let blank: Int?
    public let null: Int?
    public let valid: Int
    public let candidates: [PastCandidate]
    public let states: [PastStateTally]?

    public var id: Int { round }

    public var day: CalendarDay? { CalendarDay(date) }
}

public struct PastRace: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let year: Int
    public let office: Office
    public let scope: String
    public let scopeName: String
    public let seats: Int
    public let rounds: [PastRound]
    public let note: String?
    public let sources: [HistoryRef]
}

public struct PastPick: Codable, Hashable, Identifiable, Sendable {
    public let number: String
    public let ballotName: String
    public let party: String
    public let votes: Int
    public let share: Double
    public let elected: Bool
    public let advanced: Bool

    public var id: String { "\(number)-\(ballotName)" }
}

public struct PastRoundSummary: Codable, Hashable, Identifiable, Sendable {
    public let round: Int
    public let date: String
    public let turnout: Double?
    public let leaders: [PastPick]

    public var id: Int { round }

    public var day: CalendarDay? { CalendarDay(date) }
}

public struct PastRaceSummary: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let year: Int
    public let office: Office
    public let scope: String
    public let scopeName: String
    public let seats: Int
    public let rounds: [PastRoundSummary]

    public var finalRound: PastRoundSummary? { rounds.last }

    public var elected: [PastPick] { rounds.flatMap(\.leaders).filter(\.elected) }
}

public struct ElectionGap: Codable, Hashable, Sendable {
    public let year: Int
    public let office: Office
    public let reason: String
}

public struct ElectionHistory: Codable, Hashable, Sendable {
    public let years: [Int]
    public let races: [PastRaceSummary]
    public let gaps: [ElectionGap]
    public let method: [String]
    public let sources: [HistoryRef]
}

public struct HistoryItem: Codable, Hashable, Sendable {
    public let text: String
    public let sources: [HistoryRef]
}

public struct PeriodPresident: Codable, Hashable, Identifiable, Sendable {
    public let name: String
    public let start: String
    public let end: String?
    public let how: String
    public let sources: [HistoryRef]

    public var id: String { "\(name)-\(start)" }
}

public struct PeriodMilestone: Codable, Hashable, Identifiable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case constitution, law, economy, election, rupture, impeachment, event
    }

    public let date: String
    public let kind: Kind
    public let title: String
    public let text: String
    public let sources: [HistoryRef]

    public var id: String { "\(date)-\(title)" }

    public var day: CalendarDay? { CalendarDay(date) }
}

public struct PeriodDivergence: Codable, Hashable, Identifiable, Sendable {
    public let topic: String
    public let positions: [HistoryItem]

    public var id: String { topic }
}

public struct HistoryPoint: Codable, Hashable, Identifiable, Sendable {
    public let year: Int
    public let value: Double

    public var id: Int { year }
}

public struct PeriodIndicator: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let unit: String
    public let source: String
    public let note: String
    public let from: Int
    public let to: Int
    public let points: [HistoryPoint]
    public let average: Double?
    public let min: HistoryPoint?
    public let max: HistoryPoint?
}

public struct PoliticalPeriod: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let era: String
    public let start: String
    public let end: String?
    public let summary: String
    public let presidents: [PeriodPresident]
    public let milestones: [PeriodMilestone]
    public let advances: [HistoryItem]
    public let critiques: [HistoryItem]
    public let divergences: [PeriodDivergence]
    public let indicators: [PeriodIndicator]
    public let sources: [HistoryRef]

    public var startDay: CalendarDay? { CalendarDay(start) }

    public var endDay: CalendarDay? { end.flatMap(CalendarDay.init) }
}

public struct PoliticalTimeline: Codable, Hashable, Sendable {
    public let version: String
    public let method: [String]
    public let periods: [PoliticalPeriod]
}

public struct StudyCard: Codable, Hashable, Identifiable, Sendable {
    public let title: String
    public let text: String
    public let sources: [HistoryRef]

    public var id: String { title }
}

public struct StudyQuestion: Codable, Hashable, Identifiable, Sendable {
    public let question: String
    public let options: [String]
    public let answer: Int
    public let explanation: String
    public let sources: [HistoryRef]

    public var id: String { question }
}

public struct StudyTerm: Codable, Hashable, Identifiable, Sendable {
    public let term: String
    public let definition: String
    public let sources: [HistoryRef]

    public var id: String { term }
}

public struct StudyGuide: Codable, Hashable, Identifiable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case guide, glossary
    }

    public let id: String
    public let kind: Kind
    public let title: String
    public let summary: String
    public let cards: [StudyCard]
    public let quiz: [StudyQuestion]
    public let terms: [StudyTerm]
    public let sources: [HistoryRef]
}

public struct StudyCatalog: Codable, Hashable, Sendable {
    public let version: String
    public let method: [String]
    public let guides: [StudyGuide]
}

public enum HistoryPath {
    public static let elections = "history/elections/index.json"
    public static let periods = "history/periods.json"
    public static let study = "history/study.json"

    public static func race(id: String) -> String { "history/elections/\(id).json" }
}
