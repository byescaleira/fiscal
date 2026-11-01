import CoreGraphics
import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import FiscalResource
import Foundation
import Observation

@MainActor @Observable
public final class ShareModel {
    public typealias VideoMaker =
        @MainActor (ShareCard, CGImage?, (Double) -> Void) async throws -> URL

    public static let neutralCollection = "acervo-historico"
    public static let lastSeries = "paisagens"

    public let subject: ShareSubject
    public private(set) var phase: PublicDataPhase = .idle
    public private(set) var content: ShareCardContent?
    public private(set) var lens: Lens?
    public private(set) var code: CGImage?
    public private(set) var rendered: RenderedCard?
    public var format: ShareFormat = ShareDestination.instagramStories.format
    public var selectedWorkID: ArtWork.ID?
    public internal(set) var collectionID: ArtCollection.ID?
    public var style: ShareStyle = .poster
    public private(set) var destination: ShareDestination = .instagramStories
    public private(set) var selection = ShareSelection()
    public private(set) var caption = ""
    public private(set) var isCaptionEdited = false
    public internal(set) var exportProgress: Double = 0
    public internal(set) var isPosting = false
    public internal(set) var postFailed = false
    public internal(set) var isExportingVideo = false
    public internal(set) var videoFellBack = false
    public internal(set) var notice: ShareNotice?
    public var sendsVideo = true
    public var postRequest: SharePostRequest?

    @ObservationIgnored private let service: (any PublicDataService)?
    @ObservationIgnored private let races: (any LiveResultsService)?
    @ObservationIgnored private let lensRepository: (any LensRepository)?
    @ObservationIgnored private let follows: (any FollowRepository)?
    @ObservationIgnored var renderScale: CGFloat = 3
    @ObservationIgnored let catalog: ArtCatalog?
    @ObservationIgnored private let builder: ShareCardBuilder
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private let requests = PublicDataRequests()
    @ObservationIgnored let delivery: ShareDelivery
    @ObservationIgnored let metaAppID: String?
    @ObservationIgnored let makeVideo: VideoMaker
    @ObservationIgnored var exportedFile: URL?
    @ObservationIgnored private var didApplyDefaultStyle = false
    @ObservationIgnored var postTask: Task<Void, Never>?

    public init(
        subject: ShareSubject, service: (any PublicDataService)?,
        races: (any LiveResultsService)? = nil, lens: (any LensRepository)? = nil,
        follows: (any FollowRepository)? = nil,
        catalog: ArtCatalog? = try? ArtCatalog.bundled(),
        calendar: Calendar = GregorianCalendar.current,
        now: @escaping @Sendable () -> Date = { .now },
        delivery: ShareDelivery = .live, metaAppID: String? = ShareMetaApp.id(),
        makeVideo: @escaping VideoMaker = ShareRenderer.video
    ) {
        self.subject = subject
        self.service = service
        self.races = races
        lensRepository = lens
        self.follows = follows
        self.catalog = catalog
        builder = ShareCardBuilder(calendar: calendar)
        self.now = now
        self.delivery = delivery
        self.metaAppID = metaAppID
        self.makeVideo = makeVideo
    }

    public var isEmpty: Bool { content == nil }

    public var styles: [ShareStyle] { content?.styles ?? ShareStyle.allCases }

    public var card: ShareCard? { card(style: style) }

    public func card(style: ShareStyle) -> ShareCard? {
        content.map {
            ShareCard(
                content: $0.applying(selection), artwork: artwork,
                format: format, style: style, showsCode: selection.showsCode)
        }
    }

    public var usesArt: Bool { style == .poster }

    public var facts: [ShareFact] {
        guard let content else { return [] }
        return content.optionalFacts + (code != nil && format.showsCode ? [.code] : [])
    }

    public func isOn(_ fact: ShareFact) -> Bool { selection.isOn(fact) }

    public func canToggle(_ fact: ShareFact) -> Bool {
        selection.canToggle(fact, among: facts)
    }

    public func toggle(_ fact: ShareFact) {
        selection.toggle(fact, among: facts)
        refreshCaption()
    }

    public func choose(_ destination: ShareDestination) {
        self.destination = destination
        format = destination.format
    }

    public func editCaption(_ text: String) {
        caption = String(text.prefix(ShareCaption.limit))
        isCaptionEdited = true
    }

    public var isInvestigation: Bool { content?.investigation != nil }

    public var isVictory: Bool { content?.isVictory == true }

    public var shareMessage: String {
        guard let content else { return ShareCardBuilder.host }
        return [content.source, ShareCardBuilder.host].joined(separator: " · ")
    }

    public func render(scale: CGFloat) {
        renderScale = scale
        rendered = card.flatMap { card in
            ShareRenderer.render(card, code: code, scale: scale)
                .flatMap { RenderedCard(file: $0, scale: scale) }
        }
    }

    public func load() async {
        if content == nil { phase = .loading }
        phase = await PublicDataPhase.settle(after: phase, in: requests) {
            let lens = try? await lensRepository?.lens()
            guard let content = try await fetch().published else {
                throw PublicDataError.notFound
            }
            return (lens: lens, content: content)
        } apply: { loaded in
            lens = loaded.lens
            content = loaded.content
            if !didApplyDefaultStyle {
                didApplyDefaultStyle = true
                style = loaded.content.defaultStyle
            }
            code = ShareCode.image(for: loaded.content.link)
            refreshCaption()
        }
    }

    private func refreshCaption() {
        guard !isCaptionEdited, let content else { return }
        caption = ShareCaption.make(content, selection: selection)
    }

    private func fetch() async throws -> ShareCardContent {
        if case .race(let id) = subject { return try await race(id) }
        if case .investigation(let summary) = subject { return builder.investigation(summary) }
        if case .following = subject { return try await following() }
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
        case .investigation(let summary):
            return builder.investigation(summary)
        case .following:
            return try await following()
        }
    }

    private func following() async throws -> ShareCardContent {
        guard let follows else { throw PublicDataError.unavailable }
        let people = try await follows.followed()
        guard !people.isEmpty else { throw PublicDataError.notFound }
        return builder.following(people, at: now())
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
