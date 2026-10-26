import FeatureCore
import FiscalDomain
import Foundation

public struct InvestigationLink: Hashable, Identifiable, Sendable {
    public struct PeerStrip: Hashable, Sendable {
        public let metric: PeerClassification.Metric
        public let entry: PeerClassification.Entry
        public let median: String
        public let value: String
    }

    public struct PairRow: Hashable, Identifiable, Sendable {
        public let label: String
        public let values: [String]
        public let shares: [Double]

        public var id: String { label }
    }

    public struct Count: Hashable, Identifiable, Sendable {
        public let value: String
        public let label: String

        public var id: String { label }
    }

    public struct CheckLine: Hashable, Identifiable, Sendable {
        public let id: String
        public let title: String
        public let verdict: String?
        public let date: String
        public let url: URL
    }

    public enum Visual: Hashable, Sendable {
        case ballot(choice: BallotChoice?, vote: String, guidance: String?, followed: Bool?)
        case delegation(counts: [BallotChoice: Int], diverged: [VoteDetail.Ballot])
        case peer(PeerStrip)
        case guidance(PersonFacts.Guidance)
        case pair(faces: [PersonCard], rows: [PairRow])
        case counts([Count])
        case checks([CheckLine], total: Int)
        case highlight(HighlightRef)
        case change(before: Double?, during: Double?, name: String, months: Int)
        case results(approved: Int, rejected: Int, votes: [VoteSummary])
    }

    public let id: String
    public let question: String
    public let sentence: String
    public let source: String?
    public let pieces: [String]
    public let visual: Visual
    public let keyNumber: InvestigationSummary.KeyNumber?
    public let compared: String?
    public let uncertainty: String?
    public let route: Route?

    public init(
        id: String, question: String, sentence: String, source: String?, pieces: [String],
        visual: Visual, keyNumber: InvestigationSummary.KeyNumber? = nil,
        compared: String? = nil, uncertainty: String? = nil, route: Route? = nil
    ) {
        self.id = id
        self.question = question
        self.sentence = sentence
        self.source = source
        self.pieces = pieces
        self.visual = visual
        self.keyNumber = keyNumber
        self.compared = compared
        self.uncertainty = uncertainty
        self.route = route
    }
}

public struct InvestigationConclusion: Hashable, Sendable {
    public static let numberLimit = 3

    public let reading: String
    public let numbers: [InvestigationSummary.KeyNumber]
    public let compared: [String]
    public let uncertainty: [String]
    public let sources: [Source]

    public var facts: [String] {
        numbers.map { "\($0.label): \($0.value)" } + compared
    }
}

public struct InvestigationBoard: Hashable, Sendable {
    public let links: [InvestigationLink]
    public let notes: [String]
    public let hints: [String]
    public let sources: [Source]
    public let updatedAt: Date?

    public static let empty = InvestigationBoard(
        links: [], notes: [], hints: [], sources: [], updatedAt: nil)

    public var isEmpty: Bool { links.isEmpty }

    public var conclusion: InvestigationConclusion? {
        guard !links.isEmpty else { return nil }
        let sentences = links.prefix(2).map(\.sentence)
        var seen = Set<String>()
        let numbers = links.compactMap(\.keyNumber).filter { seen.insert($0.label).inserted }
        var uncertainty = links.compactMap(\.uncertainty) + notes
        uncertainty = uncertainty.reduce(into: []) { list, item in
            if !list.contains(item) { list.append(item) }
        }
        let compared = links.compactMap(\.compared).reduce(into: [String]()) { list, item in
            if !list.contains(item) { list.append(item) }
        }
        return InvestigationConclusion(
            reading: sentences.joined(separator: " "),
            numbers: Array(numbers.prefix(InvestigationConclusion.numberLimit)),
            compared: compared, uncertainty: uncertainty, sources: sources)
    }

    public var facts: [String] {
        links.map(\.sentence) + (conclusion?.facts ?? [])
    }
}
