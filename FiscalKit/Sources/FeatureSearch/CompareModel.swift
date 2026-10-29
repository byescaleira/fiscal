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
    @ObservationIgnored private let requests = PublicDataRequests()

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

    public var peerItems: [PeerMethodItem] {
        profiles.compactMap { profile in
            profile.classification.map { PeerMethodItem(name: profile.name, classification: $0) }
        }
    }

    public var showsLensBadge: Bool { !(lens?.themes.isEmpty ?? true) }

    public var sourceLine: String? { SourceLine.text(profiles.flatMap(\.sources)) }

    public var share: Route? { canCompare && !isEmpty ? .share(.compare(slugs: slugs)) : nil }

    public var canAdd: Bool { slugs.count < Self.range.upperBound }

    public func missingText(for group: CompareTable.Group) -> String? {
        guard !group.missing.isEmpty else { return nil }
        let list = group.missing.formatted(.list(type: .and).locale(.app))
        return String(appLocalized: "Not published for these offices: \(list)")
    }

    public var choiceText: String {
        String(appLocalized: "\(slugs.count) of \(Self.range.upperBound) chosen")
    }

    public var pickerResults: [PersonCard] {
        let terms = pickerQuery.searchWords
        guard !terms.isEmpty else { return people }
        return index.people.filter { $0.words.matchesSearch(terms) }.map(\.value)
    }

    public var chosen: [PersonCard] {
        slugs.compactMap { slug in people.first { $0.slug == slug } }
    }

    public func detail(for card: PersonCard) -> String {
        card.uf == "br" ? card.officeTitle : "\(card.officeTitle) · \(card.uf.uppercased())"
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
        phase = await PublicDataPhase.settle(after: phase, in: requests) {
            guard let service else { throw PublicDataError.unavailable }
            var loaded: [Profile] = []
            for slug in slugs { loaded.append(try await service.profile(slug: slug)) }
            return SearchIndex.alphabetical(loaded, by: \.name)
        } apply: { loaded in
            profiles = loaded
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
