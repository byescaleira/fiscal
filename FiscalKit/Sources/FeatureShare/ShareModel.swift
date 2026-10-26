import CoreGraphics
import FeatureCore
import FiscalDomain
import FiscalResource
import Foundation
import Observation

@MainActor @Observable
public final class ShareModel {
    public static let neutralCollection = "acervo-historico"
    public static let lastSeries = "paisagens"

    public let subject: ShareSubject
    public private(set) var phase: PublicDataPhase = .idle
    public private(set) var content: ShareCardContent?
    public private(set) var lens: Lens?
    public private(set) var code: CGImage?
    public var format: ShareFormat = .stories
    public var selectedWorkID: ArtWork.ID?

    @ObservationIgnored private let service: (any PublicDataService)?
    @ObservationIgnored private let races: (any LiveResultsService)?
    @ObservationIgnored private let lensRepository: (any LensRepository)?
    @ObservationIgnored private let catalog: ArtCatalog?
    @ObservationIgnored private let builder: ShareCardBuilder

    public init(
        subject: ShareSubject, service: (any PublicDataService)?,
        races: (any LiveResultsService)? = nil, lens: (any LensRepository)? = nil,
        catalog: ArtCatalog? = try? ArtCatalog.bundled(),
        calendar: Calendar = FiscalCalendar.current
    ) {
        self.subject = subject
        self.service = service
        self.races = races
        lensRepository = lens
        self.catalog = catalog
        builder = ShareCardBuilder(calendar: calendar)
    }

    public var isEmpty: Bool { content == nil }

    public var card: ShareCard? {
        content.map { ShareCard(content: $0, artwork: artwork, format: format) }
    }

    public var shareMessage: String {
        guard let content else { return ShareCardBuilder.host }
        return [content.source, ShareCardBuilder.host].joined(separator: " · ")
    }

    public var isArtAdapted: Bool {
        guard let id = lens?.artCollection else { return false }
        return catalog?.collection(id: id) != nil
    }

    public var showsLensBadge: Bool { isArtAdapted }

    public var collections: [ArtCollection] {
        guard let catalog else { return [] }
        let preferred = preferredCollectionID
        return catalog.collections.filter { $0.id == preferred }
            + catalog.collections.filter { $0.id != preferred }
    }

    public var works: [ArtWork] {
        guard let catalog else { return [] }
        return collections.flatMap { collection in
            let works = catalog.works(in: collection.id)
            return works.filter { $0.series != Self.lastSeries }
                + works.filter { $0.series == Self.lastSeries }
        }
    }

    public var artwork: ShareArtwork? {
        guard let catalog, let work = selectedWork else { return nil }
        return ShareArtwork(
            work: work, palette: catalog.collection(id: work.collection)?.palette ?? [])
    }

    public var selectedWork: ArtWork? {
        guard let catalog else { return nil }
        if let selectedWorkID, let work = catalog.work(id: selectedWorkID) { return work }
        return catalog.collection(id: preferredCollectionID).flatMap(catalog.leadWork(of:))
            ?? catalog.works.first
    }

    public func isSelected(_ work: ArtWork) -> Bool {
        selectedWork?.id == work.id
    }

    public func select(_ work: ArtWork) {
        selectedWorkID = work.id
    }

    public func load() async {
        if content == nil { phase = .loading }
        phase = await PublicDataPhase.settle(after: phase) {
            lens = try? await lensRepository?.lens()
            content = try await fetch()
            code = content.flatMap { ShareCode.image(for: $0.link) }
        }
    }

    private var preferredCollectionID: ArtCollection.ID {
        let ids = catalog?.collections.map(\.id) ?? []
        if ids.contains(Self.neutralCollection) { return Self.neutralCollection }
        if let chosen = lens?.artCollection, ids.contains(chosen) { return chosen }
        return ids.first ?? Self.neutralCollection
    }

    private func fetch() async throws -> ShareCardContent {
        if case .race(let id) = subject { return try await race(id) }
        guard let service else { throw PublicDataError.unavailable }
        return try await fetch(from: service)
    }

    private func fetch(from service: any PublicDataService) async throws -> ShareCardContent {
        switch subject {
        case .person(let slug):
            return builder.person(try await service.profile(slug: slug))
        case .vote(let id):
            return builder.vote(try await service.vote(id: id))
        case .expenses(let slug, let year):
            async let profile = service.profile(slug: slug)
            async let list = service.expenses(slug: slug, year: year)
            return builder.expenses(try await profile, list: try await list, year: year)
        case .compare(let slugs):
            guard !slugs.isEmpty else { throw PublicDataError.notFound }
            var profiles: [Profile] = []
            for slug in slugs { profiles.append(try await service.profile(slug: slug)) }
            return builder.compare(profiles)
        case .representatives(let uf):
            let place = try await service.representatives(uf: uf)
            guard place.groups.contains(where: { !$0.people.isEmpty }) else {
                throw PublicDataError.notFound
            }
            return builder.representatives(place)
        case .race(let id):
            return try await race(id)
        case .highlight(let id):
            return try await highlight(id, from: service)
        }
    }

    private func highlight(_ id: String, from service: any PublicDataService) async throws
        -> ShareCardContent
    {
        guard let list = try await service.highlights(),
            let item = list.items.first(where: { $0.id == id })
        else { throw PublicDataError.notFound }
        let vote = item.kind == .vote ? try? await service.vote(id: item.route) : nil
        var stage = item.stage.flatMap { key in list.method?.stages.first { $0.key == key }?.label }
        if stage == nil, item.kind == .action, let slug = item.person?.slug,
            let actions = try? await service.actions(slug: slug),
            let key = actions.items.first(where: { $0.id == id || "action-\($0.id)" == id })?
                .stage
        {
            stage = list.method?.stages.first { $0.key == key }?.label
        }
        return builder.highlight(item, vote: vote, stage: stage, sources: list.sources)
    }

    private func race(_ id: String) async throws -> ShareCardContent {
        guard let races else { throw PublicDataError.unavailable }
        guard let race = try await races.races().first(where: { $0.id == id }) else {
            throw PublicDataError.notFound
        }
        return builder.race(race)
    }
}
