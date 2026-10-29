import FeatureCore
import FiscalDomain
import Foundation
import Observation

@MainActor @Observable
public final class InvestigationModel {
    public var question = ""
    public var isBoardOpen = false
    public var picking: InvestigationPiece.Kind?
    public var pickerQuery = ""
    public internal(set) var current: Investigation?
    public private(set) var board = InvestigationBoard.empty
    public private(set) var phase: PublicDataPhase = .idle
    public private(set) var writing: InvestigationWriting?
    public private(set) var origin: InvestigationPlan.Origin?
    public private(set) var isReading = false
    public internal(set) var saved: [Investigation] = []
    public internal(set) var isOnDevice = true
    public private(set) var suggestions: [InvestigationSuggestion] = []
    public private(set) var highlights: [Highlight] = []
    public private(set) var followed: [PersonCard] = []
    public private(set) var lens: Lens?
    public internal(set) var renaming: Investigation?
    public var renameText = ""
    var titleEdit: TitleEdit?
    @ObservationIgnored var index = SearchIndex()
    @ObservationIgnored var recent: [VoteSummary] = []
    @ObservationIgnored private let service: (any PublicDataService)?
    @ObservationIgnored private let lensRepository: (any LensRepository)?
    @ObservationIgnored private let follows: (any FollowRepository)?
    @ObservationIgnored let repository: (any InvestigationRepository)?
    @ObservationIgnored let legacy: DeviceInvestigations?
    @ObservationIgnored var saving: Task<Void, Never>?
    @ObservationIgnored let now: @Sendable () -> Date
    @ObservationIgnored let homeUF: String?
    @ObservationIgnored let planner: InvestigationPlanner
    private var revision = 0

    public init(
        service: (any PublicDataService)?, lens: (any LensRepository)? = nil,
        follows: (any FollowRepository)? = nil,
        repository: (any InvestigationRepository)? = nil, homeUF: String? = nil,
        legacy: DeviceInvestigations? = DeviceInvestigations(), usesModel: Bool = true,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.service = service
        lensRepository = lens
        self.follows = follows
        self.homeUF = homeUF
        self.repository = repository
        self.legacy = legacy
        self.now = now
        planner = InvestigationPlanner(usesModel: usesModel)
    }

    public var usesIntelligence: Bool { planner.isAvailable }

    public var pieces: [InvestigationPiece] { current?.pieces ?? [] }

    public var isSaved: Bool {
        guard let current else { return false }
        return saved.contains { $0.id == current.id }
    }

    public var isPinned: Bool { current?.isPinned ?? false }

    public var hasData: Bool {
        _ = revision
        return !index.isEmpty
    }

    public var conclusion: InvestigationConclusion? { board.conclusion }

    public var reading: InvestigationWriting? {
        guard let conclusion else { return nil }
        return writing ?? InvestigationWriting(text: conclusion.reading, origin: .fixed)
    }

    public var isStale: Bool { phase.error != nil && !board.isEmpty }

    public var updatedText: String? {
        board.updatedAt.map { String(appLocalized: "Data from \(PublicFormat.updated($0))") }
    }

    func prepare(index: SearchIndex, recent: [VoteSummary]) {
        self.index = index
        self.recent = recent
        revision += 1
        suggestions = makeSuggestions()
    }

    public func load() async {
        await loadSaved()
        lens = try? await lensRepository?.lens()
        followed = (try? await follows?.followed())?.map(\.card) ?? []
        if highlights.isEmpty, let list = try? await service?.highlights() {
            highlights = list.items
        }
        suggestions = makeSuggestions()
    }

    public func investigate() async {
        let text = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isReading = true
        let reader = QuestionReader.plan(text, index: index)
        let model = await planner.plan(text, index: index)
        isReading = false
        var plan = reader
        if let model, !model.isEmpty {
            plan = reader.merged(with: model)
            origin = .model
        } else {
            origin = .reader
        }
        let found = InvestigationResolver.pieces(for: plan, index: index, highlights: highlights)
        await open(Investigation(question: text, pieces: found, createdAt: now(), updatedAt: now()))
    }

    public func open(_ suggestion: InvestigationSuggestion) async {
        origin = nil
        await open(
            Investigation(
                question: suggestion.question, pieces: suggestion.pieces, createdAt: now(),
                updatedAt: now()))
    }

    public func open(_ investigation: Investigation) async {
        current = investigation
        if !isSaved { persist(investigation) }
        board = .empty
        writing = nil
        isBoardOpen = true
        await refresh()
    }

    public func start(with kind: InvestigationPiece.Kind) async {
        origin = nil
        current = Investigation(question: "", createdAt: now(), updatedAt: now())
        board = .empty
        writing = nil
        phase = .loaded
        isBoardOpen = true
        picking = kind
    }

    public func add(_ piece: InvestigationPiece) async {
        guard var investigation = current else { return }
        investigation.add(piece)
        investigation.updatedAt = now()
        current = investigation
        persist(investigation)
        await refresh()
    }

    public func remove(_ piece: InvestigationPiece) async {
        guard var investigation = current else { return }
        investigation.remove(piece)
        investigation.updatedAt = now()
        current = investigation
        persist(investigation)
        await refresh()
    }

    public func refresh() async {
        guard let investigation = current else { return }
        guard !investigation.pieces.isEmpty else {
            board = .empty
            phase = .loaded
            return
        }
        guard let service else {
            phase = .failed(.unavailable)
            return
        }
        phase = .loading
        let engine = InvestigationEngine(service: service)
        let pieces = investigation.pieces
        let recent = recent
        phase = await PublicDataPhase.settle(after: phase) {
            let evidence = try await engine.evidence(for: pieces, recent: recent)
            board = InvestigationLinks(pieces: pieces, evidence: evidence).board()
            writing = nil
        }
        guard phase == .loaded, let conclusion = board.conclusion,
            var updated = current, updated.id == investigation.id
        else { return }
        let keyNumber = conclusion.numbers.first.map { "\($0.value) · \($0.label)" }
        if updated.conclusion != conclusion.reading || updated.keyNumber != keyNumber {
            updated.conclusion = conclusion.reading
            updated.keyNumber = keyNumber
            current = updated
            persist(updated)
        }
        let facts = board.facts
        let result = await planner.summary(facts: facts, fixed: conclusion.reading)
        if current?.id == updated.id { writing = result }
    }

    public var summary: InvestigationSummary? {
        guard let current, let conclusion = board.conclusion else { return nil }
        var names: [String] = []
        for source in conclusion.sources where !names.contains(source.name) {
            names.append(source.name)
        }
        return InvestigationSummary(
            id: current.id.uuidString, question: current.title,
            conclusion: board.links.first?.sentence ?? conclusion.reading,
            numbers: conclusion.numbers,
            faces: current.pieces.people.prefix(5).map {
                InvestigationSummary.Face(slug: $0.slug, name: $0.name, party: $0.party)
            },
            compared: conclusion.compared.first, uncertainty: conclusion.uncertainty.first,
            sources: names, updatedAt: board.updatedAt ?? now())
    }

    public var share: Route? { summary.map { .share(.investigation($0)) } }
}
