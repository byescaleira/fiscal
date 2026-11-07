import FiscalDomain
import Foundation

public enum InvestigationMetric: String, CaseIterable, Codable, Sendable {
    case presence, quota, proposals, speeches, votes, guidance, checks, highlights, context
}

public struct InvestigationPlan: Hashable, Sendable {
    public enum Origin: Hashable, Sendable {
        case model, reader
    }

    public var people: [String] = []
    public var party: String?
    public var state: String?
    public var city: String?
    public var theme: Theme?
    public var vote: String?
    public var metrics: [InvestigationMetric] = []
    public var comparesPeers = false
    public var beforeAndDuring = false
    public var origin: Origin = .reader

    public init() {}

    public var isEmpty: Bool {
        people.isEmpty && party == nil && state == nil && city == nil && theme == nil
            && vote == nil && metrics.isEmpty
    }

    public func merged(with other: InvestigationPlan) -> InvestigationPlan {
        var plan = self
        for name in other.people where !plan.people.contains(name) { plan.people.append(name) }
        plan.party = plan.party ?? other.party
        plan.state = plan.state ?? other.state
        plan.city = plan.city ?? other.city
        plan.theme = plan.theme ?? other.theme
        plan.vote = plan.vote ?? other.vote
        for metric in other.metrics where !plan.metrics.contains(metric) {
            plan.metrics.append(metric)
        }
        plan.comparesPeers = plan.comparesPeers || other.comparesPeers
        plan.beforeAndDuring = plan.beforeAndDuring || other.beforeAndDuring
        return plan
    }
}

enum QuestionReader {
    static let metricWords: [(String, InvestigationMetric)] = [
        ("gast", .quota), ("cota", .quota), ("dinheiro", .quota), ("despes", .quota),
        ("presen", .presence), ("falt", .presence), ("propost", .proposals),
        ("projet", .proposals), ("discurs", .speeches), ("votou", .votes), ("voto", .votes),
        ("votac", .votes), ("orientac", .guidance), ("checag", .checks), ("falso", .checks),
        ("comprova", .checks), ("destaque", .highlights), ("inflac", .context),
        ("preco", .context), ("gasolina", .context),
    ]

    static let compareWords = ["compar", "colega", "mediana", "media", "pares"]
    static let contextWords = ["antes", "durante", "posse", "desde que"]

    static func plan(_ question: String, index: SearchIndex) -> InvestigationPlan {
        var plan = InvestigationPlan()
        let folded = " \(question.searchWords.joined(separator: " ")) "
        plan.people = people(in: folded, index: index)
        plan.party = party(in: question, index: index)
        plan.state = state(in: question, folded: folded, index: index)
        plan.theme = theme(in: folded)
        plan.vote = vote(in: question, index: index)
        plan.metrics = metricWords.compactMap { word, metric in
            folded.contains(word) ? metric : nil
        }
        .reduce(into: []) { list, metric in if !list.contains(metric) { list.append(metric) } }
        if folded.contains("contra") && folded.contains("partido") {
            plan.metrics.append(.guidance)
        }
        plan.comparesPeers = compareWords.contains { folded.contains($0) }
        plan.beforeAndDuring = contextWords.contains { folded.contains(" \($0)") }
        if plan.beforeAndDuring, !plan.metrics.contains(.context) { plan.metrics.append(.context) }
        return plan
    }

    static func people(in folded: String, index: SearchIndex) -> [String] {
        var found: [String] = []
        for entry in index.people {
            let name = entry.value.name.searchWords
            guard name.count > 1 || (name.first?.count ?? 0) >= 4 else { continue }
            if folded.contains(" \(name.joined(separator: " ")) ") {
                found.append(entry.value.slug)
            }
        }
        return Array(found.prefix(Investigation.pieceLimit))
    }

    static func party(in question: String, index: SearchIndex) -> String? {
        let words = question.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        return index.parties.first { entry in
            let party = entry.value.party
            return words.contains { $0 == party || ($0.count >= 2 && $0 == party.uppercased()) }
        }?.value.party
    }

    static func state(in question: String, folded: String, index: SearchIndex) -> String? {
        let words = question.split { !$0.isLetter }.map(String.init)
        if let code = words.first(where: {
            $0.count == 2 && $0 == $0.uppercased() && HomePlace.states.contains($0.lowercased())
        }) {
            return code.lowercased()
        }
        let states = index.places.map(\.value).filter(\.isState)
        return states.first { place in
            folded.contains(" \(place.name.searchWords.joined(separator: " ")) ")
        }?.uf
    }

    static func theme(in folded: String) -> Theme? {
        Theme.allCases.first { theme in
            let key = theme.rawValue.searchWords.joined(separator: " ")
            let first = theme.title.searchWords.first ?? key
            return folded.contains(" \(key)") || (first.count >= 5 && folded.contains(" \(first)"))
        }
    }

    static func vote(in question: String, index: SearchIndex) -> String? {
        guard let match = question.firstMatch(of: /(?i)(PLP|PEC|PDL|MPV|PL)\s*(\d+)/) else {
            return nil
        }
        let kind = String(match.output.1).uppercased()
        let number = String(match.output.2)
        return index.votes.first { entry in
            let words = entry.value.proposition.searchWords
            return words.first == kind.lowercased() && words.dropFirst().first == number
        }?.value.id
    }
}

enum InvestigationResolver {
    static func pieces(
        for plan: InvestigationPlan, index: SearchIndex, highlights: [Highlight]
    ) -> [InvestigationPiece] {
        var pieces: [InvestigationPiece] = []
        let cards = plan.people.compactMap { key in person(key, index: index) }
        for card in cards {
            pieces.append(.person(card))
            if plan.metrics.contains(.quota) || plan.comparesPeers {
                pieces.append(.spending(card))
            }
            if plan.metrics.contains(.checks) { pieces.append(.checks(card)) }
            if plan.metrics.contains(.context) { pieces.append(.context(card)) }
            if plan.metrics.contains(.highlights),
                let item = highlights.first(where: { $0.person?.slug == card.slug })
            {
                pieces.append(.highlight(HighlightRef(item)))
            }
        }
        if let text = plan.vote, let vote = vote(text, index: index) {
            pieces.append(.vote(vote))
        } else if plan.metrics.contains(.votes) || plan.metrics.contains(.guidance),
            let theme = plan.theme,
            let vote = index.votes.first(where: { $0.value.themes.contains(theme) })?.value
        {
            pieces.append(.vote(vote))
        }
        if let uf = plan.state,
            let place = index.places.first(where: { $0.value.isState && $0.value.uf == uf })?.value
        {
            pieces.append(.place(place))
        }
        if let party = plan.party { pieces.append(.party(party)) }
        if let theme = plan.theme { pieces.append(.theme(theme)) }
        var seen = Set<String>()
        return Array(pieces.filter { seen.insert($0.id).inserted }.prefix(Investigation.pieceLimit))
    }

    static func vote(_ text: String, index: SearchIndex) -> VoteSummary? {
        if let vote = index.votes.first(where: { $0.value.id == text })?.value { return vote }
        if let id = QuestionReader.vote(in: text, index: index) {
            return index.votes.first { $0.value.id == id }?.value
        }
        let terms = text.searchWords
        guard !terms.isEmpty else { return nil }
        return index.votes.first { $0.words.matchesSearch(terms) }?.value
    }

    static func person(_ key: String, index: SearchIndex) -> PersonCard? {
        if let card = index.people.first(where: { $0.value.slug == key })?.value { return card }
        let terms = key.searchWords
        guard !terms.isEmpty else { return nil }
        let matches = index.people.filter { $0.words.matchesSearch(terms) }
        return matches.count == 1
            ? matches.first?.value
            : matches.first {
                $0.value.name.searchWords == terms
            }?.value
    }
}
