import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import FiscalResource
import Foundation
import Observation

@MainActor @Observable
public final class LensSetupModel {
    public enum Step: Int, CaseIterable, Identifiable, Sendable {
        case welcome, support, themes, look

        public var id: Int { rawValue }

        static var counted: [Step] { [.support, .themes, .look] }
    }

    public static let suggestionLimit = 40
    public static let resultLimit = 80

    public private(set) var step: Step
    public private(set) var draft: Lens
    public private(set) var isFinished = false
    public private(set) var isSaving = false
    public private(set) var movesForward = true
    public private(set) var appIcon: AppIcon
    public private(set) var people: [PersonCard] = []
    public private(set) var nearby: [PersonCard] = []
    public private(set) var isLoadingPeople = false
    public private(set) var activity: [SupportActivity] = []
    public private(set) var isLoadingActivity = false
    public var query = ""
    public let catalog: ArtCatalog?
    public let editing: Step?
    @ObservationIgnored private let context: LensContext
    @ObservationIgnored private let icons: (any AppIconSwitching)?
    @ObservationIgnored private let service: (any PublicDataService)?
    @ObservationIgnored private let follows: (any FollowRepository)?
    @ObservationIgnored private let placeCode: String?
    @ObservationIgnored private var known: [String: PersonCard] = [:]
    @ObservationIgnored private var themesTouched: Bool

    public init(
        context: LensContext, catalog: ArtCatalog?, editing: Step? = nil,
        icons: (any AppIconSwitching)? = nil, service: (any PublicDataService)? = nil,
        follows: (any FollowRepository)? = nil,
        placeCode: String? = UserDefaults.standard.string(forKey: HomePlace.mineKey)
    ) {
        let start = context.saved ?? Lens.suggested()
        self.context = context
        self.icons = icons
        self.service = service
        self.follows = follows
        self.placeCode = placeCode
        appIcon = icons?.current ?? .standard
        self.catalog = catalog
        self.editing = editing
        draft = start
        step = editing ?? .welcome
        themesTouched = editing == .themes || (context.saved?.hasChoice == true)
    }

    public var isEditing: Bool { editing != nil }

    public var palettePairs: [[LensPaletteSwatch]] {
        LensPaletteSwatch.leading.map { [$0, $0.mirror] }
    }

    public var collections: [ArtCollection] { catalog?.collections ?? [] }

    public var stepIndex: Int { (Step.counted.firstIndex(of: step) ?? -1) + 1 }

    public var progress: Double { Double(stepIndex) / Double(Step.counted.count) }

    public var stepText: String {
        String(appLocalized: "Step \(stepIndex) of \(Step.counted.count)")
    }

    public var canContinue: Bool {
        switch step {
        case .welcome: true
        case .support: draft.hasChoice
        case .themes: draft.isComplete
        case .look: palette != nil && draft.artCollection != nil
        }
    }

    public var primaryTitle: String {
        if isEditing { return String(appLocalized: "Save") }
        return switch step {
        case .welcome: String(appLocalized: "Start · 1 min")
        case .support, .themes: String(appLocalized: "Continue")
        case .look: String(appLocalized: "Done")
        }
    }

    public var canGoBack: Bool { !isEditing && step != .welcome }

    public var isLastStep: Bool { isEditing || step == .look }

    public var palette: LensPaletteSwatch? { LensPaletteSwatch.named(draft.palette) }

    public var collection: ArtCollection? {
        draft.artCollection.flatMap { catalog?.collection(id: $0) }
    }

    public var backdrop: ArtWork? {
        if let collection, let work = catalog?.leadWork(of: collection) { return work }
        return welcomeWorks.first
    }

    public var welcomeWorks: [ArtWork] {
        guard let catalog else { return [] }
        let leads = catalog.collections.compactMap { catalog.leadWork(of: $0) }
        let others = catalog.works.filter { !leads.contains($0) }
        return Array((leads + others).prefix(7))
    }

    public func works(in collection: ArtCollection) -> [ArtWork] {
        guard let catalog else { return [] }
        let lead = catalog.leadWork(of: collection)
        let rest = catalog.works(in: collection.id).filter { $0 != lead }
        return [lead].compactMap { $0 } + rest
    }

    public func isChosen(_ swatch: LensPaletteSwatch) -> Bool { palette == swatch }

    public func isChosen(_ collection: ArtCollection) -> Bool {
        draft.artCollection == collection.id
    }

    public func choose(_ swatch: LensPaletteSwatch) {
        draft.palette = swatch.rawValue
    }

    public func choose(_ collection: ArtCollection) {
        draft.artCollection = collection.id
    }

    public var supportsIcons: Bool { icons?.supportsAlternateIcons == true }

    public func choose(_ icon: AppIcon) async {
        guard let icons, icon != appIcon else { return }
        let previous = appIcon
        appIcon = icon
        if (try? await icons.set(icon)) == nil {
            appIcon = previous
        } else {
            draft.icon = icon.rawValue
        }
    }

    public func advance() async {
        guard canContinue else { return }
        if isLastStep {
            await finish()
        } else if let next = Step(rawValue: step.rawValue + 1) {
            movesForward = true
            step = next
        }
    }

    public func goBack() {
        guard canGoBack, let previous = Step(rawValue: step.rawValue - 1) else { return }
        movesForward = false
        step = previous
    }

    public func finish() async {
        guard !isSaving else { return }
        isSaving = true
        isFinished = await context.save(draft)
        if isFinished { await SupportedPeople.follow(chosen, in: follows) }
        isSaving = false
    }
}

extension LensSetupModel {
    public var chosen: [PersonCard] { draft.supported.compactMap { known[$0] } }

    public var openSlots: Int { max(Lens.supportLimit - draft.supported.count, 0) }

    public var supportCountText: String {
        String(
            appLocalized: "\(draft.supported.count) of \(Lens.supportLimit) people chosen")
    }

    public var results: [PersonCard] {
        let text = Self.fold(query.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !text.isEmpty else { return Array(suggestions.prefix(Self.suggestionLimit)) }
        let pool = Self.unique(nearby + people)
        return Array(
            pool.filter { card in
                Self.fold("\(card.name) \(card.party) \(card.officeTitle) \(card.uf)")
                    .contains(text)
            }
            .prefix(Self.resultLimit))
    }

    public var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var suggestions: [PersonCard] {
        let leaders = people.filter { [.president, .vicePresident, .governor].contains($0.office) }
        return Self.unique(chosen + nearby + leaders + people)
    }

    public func isSupported(_ card: PersonCard) -> Bool { draft.supports(card.slug) }

    public func canToggle(_ card: PersonCard) -> Bool {
        isSupported(card) || draft.canAddSupport
    }

    public func detail(for card: PersonCard) -> String {
        card.uf == "br" ? card.officeTitle : "\(card.officeTitle) · \(card.uf.uppercased())"
    }

    public func toggle(_ card: PersonCard) async {
        known[card.slug] = card
        draft.toggleSupport(card.slug)
        await refreshActivity()
    }

    public func choosePrefersNotToSay() async {
        draft.choosePrefersNotToSay()
        await refreshActivity()
    }

    public func loadPeople() async {
        guard let service, people.isEmpty, !isLoadingPeople else { return }
        isLoadingPeople = true
        async let everyone = try? service.people()
        async let city = loadNearby(service)
        let list = await everyone ?? []
        nearby = await city
        people = list
        for card in Self.unique(nearby + list) where draft.supports(card.slug) {
            known[card.slug] = card
        }
        let missing = draft.supported.filter { known[$0] == nil }
        for card in await SupportedPeople.cards(for: missing, service: nil, follows: follows) {
            known[card.slug] = card
        }
        isLoadingPeople = false
        if activity.isEmpty, !draft.supported.isEmpty { await refreshActivity() }
    }

    public func refreshActivity() async {
        let cards = chosen
        isLoadingActivity = !cards.isEmpty
        let found = await SupportedPeople.activity(for: cards, service: service)
        guard cards == chosen else { return }
        activity = found
        isLoadingActivity = false
        if !themesTouched {
            draft.replaceThemes(
                SupportThemes.suggested(found, prefersNotToSay: draft.prefersNotToSay))
        }
    }

    private func loadNearby(_ service: any PublicDataService) async -> [PersonCard] {
        guard let placeCode, placeCode.count > 2,
            let city = try? await service.cityRepresentatives(code: placeCode)
        else { return [] }
        return city.groups.flatMap(\.people)
    }

    static func fold(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
    }

    static func unique(_ cards: [PersonCard]) -> [PersonCard] {
        var seen: Set<String> = []
        return cards.filter { seen.insert($0.slug).inserted }
    }
}

extension LensSetupModel {
    public var entries: [SupportThemes.Entry] { SupportThemes.ranked(activity) }

    public var maxEntryCount: Int { entries.map(\.count).max() ?? 0 }

    public func entry(for theme: Theme) -> SupportThemes.Entry? {
        entries.first { $0.theme == theme }
    }

    public var themeCountText: String {
        String(
            appLocalized:
                "\(draft.themes.count) of \(Lens.themeRange.upperBound) topics chosen")
    }

    public var themesMessage: String {
        if draft.prefersNotToSay || draft.supported.isEmpty {
            return String(
                appLocalized:
                    "In the order the data comes. Put first what matters to you, from 3 to 5 topics."
            )
        }
        if entries.isEmpty {
            return String(
                appLocalized:
                    "No recent actions of the people you support yet. Choose from 3 to 5 topics."
            )
        }
        return String(
            appLocalized:
                "Ordered by what the people you support do the most. Reorder or remove as you like. \(themesBasis)"
        )
    }

    public var themesBasis: String {
        let counted = activity.filter { !$0.counts.isEmpty }
        let names = counted.map(\.name).formatted(.list(type: .and).locale(.app))
        if counted.allSatisfy(\.usesActions) {
            let total = PublicFormat.number(counted.reduce(0) { $0 + $1.actionCount })
            return String(
                appLocalized:
                    "Calculated from \(total) recent actions of \(names). Estimated: each action's topic comes from keywords in its official summary and can miss."
            )
        }
        return String(
            appLocalized:
                "Calculated from the proposals and speeches of \(names). Estimated: each one's topic comes from keywords in its official summary and can miss."
        )
    }

    public var otherThemes: [Theme] {
        let order = SupportThemes.order(activity)
        return order.filter { !draft.contains($0) }
    }

    public func actionsText(for entry: SupportThemes.Entry) -> String {
        let names = entry.names.formatted(.list(type: .and).locale(.app))
        let count = PublicFormat.number(entry.count)
        return String(appLocalized: "\(names): \(count) actions")
    }

    public func rankText(_ index: Int) -> String { PublicFormat.number(index + 1) }

    public func add(_ theme: Theme) {
        guard draft.canAddTheme, !draft.contains(theme) else { return }
        draft.toggle(theme)
        themesTouched = true
    }

    public func remove(_ theme: Theme) {
        guard draft.canRemoveTheme, draft.contains(theme) else { return }
        draft.toggle(theme)
        themesTouched = true
    }

    public func move(_ theme: Theme, by offset: Int) {
        draft.moveTheme(theme, by: offset)
        themesTouched = true
    }

    public func move(_ theme: Theme, before other: Theme) {
        draft.moveTheme(theme, before: other)
        themesTouched = true
    }

    public func isFirst(_ theme: Theme) -> Bool { draft.themes.first == theme }

    public func isLast(_ theme: Theme) -> Bool { draft.themes.last == theme }
}
