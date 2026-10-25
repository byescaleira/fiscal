import FiscalDomain
import Foundation

public struct ShareCardContent: Hashable, Sendable {
    public enum Body: Hashable, Sendable {
        case person([ShareMetric])
        case vote(ShareTally)
        case expenses(ShareSpending)
        case race(ShareRace)
        case compare([ShareCompareRow])
        case representatives([ShareGroup])
    }

    public let eyebrow: String
    public let headline: String?
    public let faces: [ShareFace]
    public let body: Body
    public let source: String
    public let stamp: String
    public let link: URL

    public init(
        eyebrow: String, headline: String?, faces: [ShareFace], body: Body, source: String,
        stamp: String, link: URL
    ) {
        self.eyebrow = eyebrow
        self.headline = headline
        self.faces = faces
        self.body = body
        self.source = source
        self.stamp = stamp
        self.link = link
    }

    public var hasPortrait: Bool { !faces.isEmpty }

    public var texts: [String] {
        [eyebrow] + [headline].compactMap(\.self) + faces.flatMap(\.texts) + body.texts + [
            source, stamp,
        ]
    }

    public var accessibilitySummary: String {
        ([eyebrow, headline].compactMap(\.self) + faces.map(\.name) + body.texts + [source])
            .joined(separator: ", ")
    }
}

public struct ShareFace: Hashable, Sendable, Identifiable {
    public let slug: String
    public let name: String
    public let party: String
    public let detail: String

    public init(slug: String, name: String, party: String, detail: String) {
        self.slug = slug
        self.name = name
        self.party = party
        self.detail = detail
    }

    public var id: String { slug }

    var texts: [String] { [name, party, detail] }
}

public struct ShareMetric: Hashable, Sendable, Identifiable {
    public let label: String
    public let value: String

    public init(label: String, value: String) {
        self.label = label
        self.value = value
    }

    public var id: String { label }
}

public struct ShareTally: Hashable, Sendable {
    public let proposition: String
    public let official: String?
    public let yes: String
    public let no: String
    public let others: String
    public let yesShare: Double
    public let noShare: Double
    public let othersShare: Double
    public let result: String?
    public let approved: Bool?
    public let quorum: String?

    var texts: [String] {
        [proposition, official, yes, no, others, result, quorum].compactMap(\.self)
    }
}

public struct ShareSpending: Hashable, Sendable {
    public struct Category: Hashable, Sendable, Identifiable {
        public let name: String
        public let value: String
        public let share: Double

        public var id: String { name }
    }

    public let total: String
    public let caption: String
    public let receipts: String
    public let categories: [Category]

    var texts: [String] {
        [total, caption, receipts] + categories.flatMap { [$0.name, $0.value] }
    }
}

public struct ShareRace: Hashable, Sendable {
    public struct Candidate: Hashable, Sendable, Identifiable {
        public let number: String
        public let name: String
        public let party: String
        public let percent: String
        public let share: Double
        public let votes: String
        public let elected: Bool

        public var id: String { number }
    }

    public let counted: String
    public let countedShare: Double
    public let candidates: [Candidate]
    public let footnote: String

    var texts: [String] {
        [counted, footnote] + candidates.flatMap { [$0.name, $0.party, $0.percent, $0.votes] }
    }
}

public struct ShareCompareRow: Hashable, Sendable, Identifiable {
    public let label: String
    public let values: [String]

    public var id: String { label }
}

public struct ShareGroup: Hashable, Sendable, Identifiable {
    public let title: String
    public let count: String
    public let names: [String]

    public var id: String { title }
}

extension ShareCardContent.Body {
    var texts: [String] {
        switch self {
        case .person(let metrics): metrics.flatMap { [$0.label, $0.value] }
        case .vote(let tally): tally.texts
        case .expenses(let spending): spending.texts
        case .race(let race): race.texts
        case .compare(let rows): rows.flatMap { [$0.label] + $0.values }
        case .representatives(let groups): groups.flatMap { [$0.title, $0.count] + $0.names }
        }
    }
}
