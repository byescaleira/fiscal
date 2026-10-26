import FiscalDomain
import Foundation

public struct PartySummary: Hashable, Identifiable, Sendable {
    public let party: String
    public let count: Int

    public var id: String { SearchText.fold(party) }
}

public struct SearchResults: Equatable, Sendable {
    public var people: [PersonCard] = []
    public var parties: [PartySummary] = []
    public var places: [Place] = []
    public var votes: [VoteSummary] = []

    public var isEmpty: Bool {
        people.isEmpty && parties.isEmpty && places.isEmpty && votes.isEmpty
    }

    public var count: Int { people.count + parties.count + places.count + votes.count }
}

struct SearchIndex: Sendable {
    struct Entry<Value: Sendable>: Sendable {
        let value: Value
        let words: [String]
    }

    static let peopleLimit = 50
    static let groupLimit = 8

    let people: [Entry<PersonCard>]
    let parties: [Entry<PartySummary>]
    let places: [Entry<Place>]
    let votes: [Entry<VoteSummary>]

    init(people: [PersonCard] = [], places: [Place] = [], votes: [VoteSummary] = []) {
        let states = Dictionary(
            places.filter(\.isState).map { ($0.uf, $0.name) },
            uniquingKeysWith: { first, _ in first })
        self.people = Self.alphabetical(people, by: \.name).map { card in
            let text = [
                card.name, card.party, card.uf, states[card.uf] ?? "", card.officeTitle,
                SearchText.aliases(for: card.office), SearchText.aliases(for: card.status),
            ]
            return Entry(value: card, words: SearchText.words(text.joined(separator: " ")))
        }
        let counts = Dictionary(grouping: people) { SearchText.fold($0.party) }
        parties = Self.alphabetical(
            counts.values.compactMap { group in
                group.first.map { PartySummary(party: $0.party, count: group.count) }
            }, by: \.party
        ).map { Entry(value: $0, words: SearchText.words($0.party)) }
        self.places = places.map { place in
            let state = place.isState ? "estado" : states[place.uf] ?? ""
            return Entry(
                value: place, words: SearchText.words("\(place.name) \(place.uf) \(state)"))
        }
        self.votes = votes.map { vote in
            let text = [
                vote.proposition, vote.kind ?? "", vote.summary, vote.plainSummary ?? "",
                vote.themes.map(\.title).joined(separator: " "),
            ]
            return Entry(value: vote, words: SearchText.words(text.joined(separator: " ")))
        }
    }

    var isEmpty: Bool { people.isEmpty && places.isEmpty && votes.isEmpty }

    func results(for query: String, tokens: [SearchToken] = []) -> SearchResults {
        let terms = SearchText.words(query)
        let peopleTokens = tokens.filter(\.filtersPeople)
        let themeTokens = tokens.filter { !$0.filtersPeople }
        guard !terms.isEmpty || !tokens.isEmpty else { return SearchResults() }
        var results = SearchResults()
        if themeTokens.isEmpty {
            results.people = Array(
                people.lazy
                    .filter { entry in peopleTokens.allSatisfy { $0.admits(entry.value) } }
                    .filter { SearchText.matches(terms, in: $0.words) }
                    .map(\.value)
                    .prefix(Self.peopleLimit))
        }
        if tokens.isEmpty {
            results.parties = matching(parties, terms)
            results.places = matching(places, terms)
        }
        if peopleTokens.isEmpty {
            results.votes = Array(
                votes.lazy
                    .filter { entry in themeTokens.allSatisfy { $0.admits(entry.value) } }
                    .filter { SearchText.matches(terms, in: $0.words) }
                    .map(\.value)
                    .prefix(Self.groupLimit))
        }
        return results
    }

    func count(of token: SearchToken) -> Int {
        people.count { token.admits($0.value) }
    }

    private func matching<Value>(_ entries: [Entry<Value>], _ terms: [String]) -> [Value] {
        guard !terms.isEmpty else { return [] }
        return Array(
            entries.lazy.filter { SearchText.matches(terms, in: $0.words) }.map(\.value)
                .prefix(Self.groupLimit))
    }

    static func alphabetical<Value>(_ values: [Value], by key: KeyPath<Value, String>) -> [Value] {
        values.sorted {
            $0[keyPath: key].compare(
                $1[keyPath: key], options: [.caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: "pt_BR")) == .orderedAscending
        }
    }
}
