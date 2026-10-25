import FeatureCore
import FiscalDomain
import Foundation
import Observation

@MainActor @Observable
public final class SearchModel {
    public static let resultLimit = 50

    public var query = ""
    public private(set) var people: [PersonCard] = [] {
        didSet {
            index = people.map { card in
                Self.fold("\(card.name) \(card.party) \(card.uf) \(card.office.title)")
            }
        }
    }
    public private(set) var phase: PublicDataPhase = .idle
    @ObservationIgnored private var index: [String] = []
    @ObservationIgnored private let service: (any PublicDataService)?

    public init(service: (any PublicDataService)?) {
        self.service = service
    }

    public var isSearching: Bool { !terms.isEmpty }

    public var results: [PersonCard] {
        let terms = terms
        guard !terms.isEmpty else { return [] }
        return Array(
            zip(people, index)
                .filter { _, text in terms.allSatisfy { text.contains($0) } }
                .map { $0.0 }
                .prefix(Self.resultLimit))
    }

    public func detail(for card: PersonCard) -> String {
        let place = card.uf == "br" ? "" : " · \(card.uf.uppercased())"
        return "\(card.office.title) · \(card.party)\(place)"
    }

    public func load() async {
        guard people.isEmpty else { return }
        phase = .loading
        phase = await PublicDataPhase.settle(after: phase) {
            guard let service else { throw PublicDataError.unavailable }
            people = try await service.people()
        }
    }

    private var terms: [String] {
        Self.fold(query).split(whereSeparator: \.isWhitespace).map(String.init)
    }

    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .app)
    }
}
