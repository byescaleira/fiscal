import FiscalDomain
import Foundation

public struct SharePoster: Hashable, Sendable {
    public enum Hero: Hashable, Sendable {
        case figure(value: String, caption: String)
        case place(String)
        case tally(ShareTally)
        case race(ShareRace)
        case versus([ShareFace], [ShareCompareRow])
        case highlight(ShareHighlight)
        case people([ShareFace])
    }

    public struct Fact: Hashable, Sendable, Identifiable {
        public let value: String
        public let label: String

        public var id: String { label }
    }

    public static let factLimit = 2
    public static let compareLimit = 3

    public let eyebrow: String
    public let headline: String?
    public let hero: Hero
    public let facts: [Fact]
    public let note: String?
    public let person: ShareFace?
    public let source: String
    private let isCase: Bool

    public init(_ content: ShareCardContent) {
        isCase = content.investigation != nil
        eyebrow = content.eyebrow
        source = content.source
        switch content.body {
        case .person(let metrics):
            let lead = metrics.firstIndex { $0.value != PublicFormat.missing } ?? 0
            let rest = metrics.indices.filter { $0 != lead }.map { metrics[$0] }
            headline = nil
            let leading = metrics.indices.contains(lead) ? metrics[lead] : nil
            hero = .figure(
                value: leading?.value ?? PublicFormat.missing,
                caption: leading.map {
                    [$0.label, $0.peer].compactMap(\.self).joined(separator: " · ")
                }
                    ?? "")
            facts = rest.prefix(Self.factLimit).map { Fact(value: $0.value, label: $0.label) }
            note = leading?.peerDetail
            person = content.faces.first
        case .vote(let tally):
            if tally.hasCount {
                headline = content.headline
                hero = .tally(tally)
                note = tally.proposition.isEmpty ? nil : tally.proposition
            } else {
                headline = content.headline
                hero = .place(
                    [tally.name, tally.result].compactMap(\.self).joined(separator: ": "))
                note = nil
            }
            facts = []
            person = nil
        case .expenses(let spending):
            headline = nil
            hero = .figure(value: spending.total, caption: spending.receipts)
            facts = spending.categories.prefix(1).map {
                Fact(value: $0.value, label: String(appLocalized: "Largest: \($0.name)"))
            }
            note = nil
            person = content.faces.first
        case .compare(let rows):
            headline = nil
            hero = .versus(Array(content.faces.prefix(2)), Array(rows.prefix(Self.compareLimit)))
            facts = []
            note = nil
            person = nil
        case .representatives(let groups):
            headline = nil
            hero = .place(content.headline ?? "")
            facts = groups.map { Fact(value: $0.count, label: $0.title) }
            note = nil
            person = nil
        case .race(let race):
            headline = content.headline
            hero = .race(race)
            facts = []
            note = [race.counted, race.footnote].joined(separator: " · ")
            person = nil
        case .highlight(let highlight):
            headline = nil
            hero = .highlight(highlight)
            facts = []
            let parts = [highlight.weight, highlight.shortUncertainty].compactMap(\.self)
                .filter { !$0.isEmpty }
            note = parts.isEmpty ? nil : parts.joined(separator: " · ")
            person = nil
        case .victory(let victory):
            headline = content.headline
            hero = .figure(value: victory.percent, caption: victory.statement)
            facts =
                (victory.runnerUp.map { [Fact(value: $0.percent, label: $0.face.name)] } ?? [])
                + victory.ballots.filter { $0.kind != .valid }.prefix(1).map {
                    Fact(value: $0.percent, label: $0.title)
                }
            note = nil
            person = victory.winner
        case .investigation(let investigation):
            headline = investigation.question
            if let number = investigation.numbers.first {
                hero = .figure(value: number.value, caption: number.label)
                facts = Array(investigation.numbers.dropFirst())
            } else {
                hero = .place(investigation.conclusion)
                facts = []
            }
            let parts =
                investigation.numbers.isEmpty
                ? [investigation.uncertainty]
                : [investigation.conclusion, investigation.uncertainty]
            note = parts.compactMap(\.self).joined(separator: " · ")
            person = nil
        case .following(let faces):
            headline = content.headline
            hero = .people(faces)
            facts = []
            note = nil
            person = nil
        case .receipt(let receipt):
            headline = receipt.supplier
            hero = .figure(value: receipt.amount, caption: receipt.context)
            facts = [
                Fact(value: receipt.category, label: String(appLocalized: "Kind of expense")),
                Fact(value: receipt.period, label: String(appLocalized: "Month")),
            ]
            note = nil
            person = content.faces.first
        case .ballot(let ballot):
            headline = ballot.summary
            hero = .figure(value: ballot.vote, caption: ballot.proposition)
            facts = [
                Fact(value: ballot.date, label: String(appLocalized: "Date")),
                ballot.result.map { Fact(value: $0, label: String(appLocalized: "Result")) },
            ].compactMap(\.self)
            note = nil
            person = content.faces.first
        case .proposal(let proposal):
            headline = proposal.summary
            hero = .place(proposal.reference)
            facts = []
            note = nil
            person = content.faces.first
        }
    }

    public var factsAreEssential: Bool {
        if case .place = hero { return true }
        return false
    }

    public var noteIsEssential: Bool {
        switch hero {
        case .race, .highlight: true
        case .figure, .place, .tally, .versus, .people: isCase
        }
    }

    public var texts: [String] {
        [eyebrow, headline].compactMap(\.self) + hero.texts
            + facts.flatMap { [$0.value, $0.label] } + [note].compactMap(\.self)
            + (person.map { [$0.name, $0.party] } ?? []) + [source]
    }

    public var accessibilitySummary: String {
        texts.filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

extension SharePoster.Hero {
    var texts: [String] {
        switch self {
        case .figure(let value, let caption): [value, caption]
        case .place(let name): [name]
        case .tally(let tally):
            [tally.yes, tally.no, tally.others, tally.result].compactMap(\.self)
        case .race(let race):
            race.candidates.flatMap {
                [$0.name, $0.party, $0.percent]
                    + ($0.elected ? [String(appLocalized: "Elected")] : [])
            }
        case .versus(let faces, let rows):
            faces.flatMap { [$0.name, $0.party] } + rows.flatMap { [$0.label] + $0.values }
        case .highlight(let highlight):
            [highlight.title] + (highlight.person.map { [$0.name, $0.party] } ?? [])
                + [highlight.place] + (highlight.tally.map { Self.tally($0).texts } ?? [])
        case .people(let faces): faces.flatMap { [$0.name, $0.party, $0.detail] }
        }
    }
}
