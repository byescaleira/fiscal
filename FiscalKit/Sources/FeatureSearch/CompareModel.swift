import FeatureCore
import FiscalDomain
import Foundation
import Observation

@MainActor @Observable
public final class CompareModel {
    public static let range = 2...2

    public private(set) var slugs: [String]
    public private(set) var profiles: [Profile] = []
    public private(set) var people: [PersonCard] = []
    public private(set) var lens: Lens?
    public private(set) var phase: PublicDataPhase = .idle
    public var isPicking = false
    public var pickerQuery = ""
    @ObservationIgnored private var index = SearchIndex()
    @ObservationIgnored private let service: (any PublicDataService)?
    @ObservationIgnored private let lensRepository: (any LensRepository)?

    public init(
        slugs: [String], service: (any PublicDataService)? = nil,
        lens: (any LensRepository)? = nil
    ) {
        var unique: [String] = []
        for slug in slugs where !unique.contains(slug) { unique.append(slug) }
        self.slugs = Array(unique.prefix(Self.range.upperBound))
        self.service = service
        lensRepository = lens
        phase = self.slugs.count >= Self.range.lowerBound ? .idle : .loaded
    }

    public var canCompare: Bool { slugs.count >= Self.range.lowerBound }

    public var isEmpty: Bool { !canCompare || profiles.count < Self.range.lowerBound }

    public var table: CompareTable { CompareTable(profiles: profiles, lens: lens) }

    public var badgeStance: PoliticalStance? {
        guard let lens, !lens.themes.isEmpty else { return nil }
        return lens.stance ?? .preferNotToSay
    }

    public var sourceLine: String? { SourceLine.text(profiles.flatMap(\.sources)) }

    public var share: Route? { canCompare && !isEmpty ? .share(.compare(slugs: slugs)) : nil }

    public var canAdd: Bool { slugs.count < Self.range.upperBound }

    public var choiceText: String {
        String(appLocalized: "\(slugs.count) of \(Self.range.upperBound) chosen")
    }

    public var pickerResults: [PersonCard] {
        let terms = SearchText.words(pickerQuery)
        guard !terms.isEmpty else { return people }
        return index.people.filter { SearchText.matches(terms, in: $0.words) }.map(\.value)
    }

    public var chosen: [PersonCard] {
        slugs.compactMap { slug in people.first { $0.slug == slug } }
    }

    public func detail(for card: PersonCard) -> String {
        card.uf == "br" ? card.office.title : "\(card.office.title) · \(card.uf.uppercased())"
    }

    public func isChosen(_ card: PersonCard) -> Bool { slugs.contains(card.slug) }

    public func canToggle(_ card: PersonCard) -> Bool { isChosen(card) || canAdd }

    public func toggle(_ card: PersonCard) {
        if let position = slugs.firstIndex(of: card.slug) {
            slugs.remove(at: position)
        } else if canAdd {
            slugs.append(card.slug)
        }
    }

    public func pick() async {
        isPicking = true
        await loadPeople()
    }

    public func confirm() async {
        isPicking = false
        pickerQuery = ""
        await load()
    }

    public func load() async {
        lens = try? await lensRepository?.lens()
        guard canCompare else {
            profiles = []
            phase = .loaded
            await loadPeople()
            return
        }
        let wanted = Set(slugs)
        guard Set(profiles.map(\.slug)) != wanted else { return }
        phase = .loading
        phase = await PublicDataPhase.settle(after: phase) {
            guard let service else { throw PublicDataError.unavailable }
            var loaded: [Profile] = []
            for slug in slugs { loaded.append(try await service.profile(slug: slug)) }
            profiles = SearchIndex.alphabetical(loaded, by: \.name)
        }
    }

    private func loadPeople() async {
        guard people.isEmpty, let service, let cards = try? await service.people() else {
            return
        }
        let built = await Task.detached { SearchIndex(people: cards) }.value
        index = built
        people = built.people.map(\.value)
    }
}
