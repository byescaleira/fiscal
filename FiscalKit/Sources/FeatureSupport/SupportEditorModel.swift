import FeatureCore
import FiscalDomain
import Foundation
import Observation

@MainActor @Observable
public final class SupportEditorModel {
    static let resultLimit = 30

    public private(set) var draft: SupportChoice
    public private(set) var people: [PersonCard] = []
    public private(set) var isSaving = false
    public private(set) var isFinished = false
    public var query = ""
    @ObservationIgnored private let context: SupportContext
    @ObservationIgnored private let service: (any PublicDataService)?
    @ObservationIgnored private let follows: (any FollowRepository)?
    @ObservationIgnored private var known: [String: PersonCard] = [:]

    public init(
        context: SupportContext, service: (any PublicDataService)?,
        follows: (any FollowRepository)?
    ) {
        self.context = context
        self.service = service
        self.follows = follows
        draft = context.choice
    }

    public var chosen: [PersonCard] { draft.people.compactMap { known[$0] } }

    public var peopleCount: String {
        String(appLocalized: "\(draft.people.count) of \(SupportChoice.peopleLimit)")
    }

    public var causesCount: String {
        String(appLocalized: "\(draft.causes.count) of \(SupportChoice.causeLimit)")
    }

    public var results: [PersonCard] {
        let text = Self.fold(query.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !text.isEmpty else { return [] }
        return Array(
            people.filter { card in
                !draft.supports(card.slug)
                    && Self.fold("\(card.name) \(card.party) \(card.officeTitle) \(card.uf)")
                        .contains(text)
            }
            .prefix(Self.resultLimit))
    }

    public var causes: [Theme] { Theme.causeChoices }

    public func load() async {
        guard let service else { return }
        let list = (try? await service.people()) ?? []
        people = list
        for card in list { known[card.slug] = card }
        let cards = await SupportedPeople.cards(
            for: draft.people, service: nil, follows: follows)
        for card in cards { known[card.slug] = card }
    }

    public func canAdd(_ card: PersonCard) -> Bool { draft.canAddPerson }

    public func canToggle(_ cause: Theme) -> Bool {
        draft.contains(cause) || draft.canAddCause
    }

    public func toggle(_ card: PersonCard) {
        known[card.slug] = card
        draft.togglePerson(card.slug)
    }

    public func toggle(_ cause: Theme) {
        draft.toggleCause(cause)
    }

    public func save() async {
        isSaving = true
        defer { isSaving = false }
        let previous = context.choice.people
        guard await context.save(draft) else { return }
        let added = chosen.filter { !previous.contains($0.slug) }
        await SupportedPeople.follow(added, in: follows)
        isFinished = true
    }

    static func fold(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
    }
}
