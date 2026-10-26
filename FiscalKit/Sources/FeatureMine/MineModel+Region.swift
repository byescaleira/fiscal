import FeatureCore
import FiscalDomain
import Foundation

extension MineModel {
    public var seats: [MineSeat] {
        guard let representatives else { return [] }
        let city = cityRepresentatives?.groups ?? []
        let cityName = place.map { $0.isState ? nil : $0.name } ?? nil
        let candidates: [MineSeat?] = [
            cityName.flatMap {
                Self.seat(.city, place: $0, holder: .mayor, vice: .viceMayor, in: city)
            },
            Self.seat(
                .state, place: representatives.name, holder: .governor, vice: .viceGovernor,
                in: representatives.groups),
            Self.seat(
                .country, place: String(appLocalized: "Brazil"), holder: .president,
                vice: .vicePresident, in: representatives.groups),
        ]
        return candidates.compactMap(\.self)
    }

    public var benches: [MineBench] {
        guard let representatives else { return [] }
        let stateName = representatives.name
        let city = cityRepresentatives?.groups ?? []
        let councilTitle = place.map { $0.isState ? nil : $0.name } ?? nil
        let candidates: [MineBench?] = [
            councilTitle.flatMap {
                Self.bench(
                    .cityCouncilor, title: String(appLocalized: "City Council"), place: $0,
                    in: city)
            },
            Self.bench(
                .stateDeputy,
                title: representatives.uf.lowercased() == "df"
                    ? String(appLocalized: "Legislative Chamber")
                    : String(appLocalized: "Legislative Assembly"),
                place: stateName, in: representatives.groups),
            Self.bench(
                .federalDeputy, title: House.camara.title, place: stateName,
                in: representatives.groups),
        ]
        return candidates.compactMap(\.self)
    }

    public var senate: MineBench? {
        guard let representatives else { return nil }
        return Self.bench(
            .senator, title: House.senado.title, place: representatives.name,
            in: representatives.groups)
    }

    public var regionSlugs: Set<String> {
        Set(groups.flatMap { $0.people.map(\.slug) })
    }

    public var houseSeats: [House: Int] {
        var seats: [House: Int] = [:]
        if let deputies = benches.first(where: { $0.office == .federalDeputy }) {
            seats[.camara] = deputies.total
        }
        if let senate { seats[.senado] = senate.total }
        return seats
    }

    public var followedCards: [PersonCard] { followed.map(\.card) }

    public var isLoadingActivity: Bool { activityPhase == .loading && activity.isEmpty }

    public var isOfflineWithData: Bool {
        phase.error == .offline && representatives != nil
    }

    public func leadAction(for card: PersonCard) -> ActionItem? { activity.actions[card.slug] }

    public func mandateText(for card: PersonCard) -> String? {
        guard let mandate = activity.mandates[card.slug] else { return nil }
        switch (mandate.start, mandate.end) {
        case (let start?, let end?):
            return String(appLocalized: "Term \(String(start.year))–\(String(end.year))")
        case (let start?, nil):
            return String(appLocalized: "Term since \(String(start.year))")
        case (nil, let end?):
            return String(appLocalized: "Term until \(String(end.year))")
        case (nil, nil):
            return nil
        }
    }

    public func actionKicker(_ item: ActionItem) -> String {
        let kind =
            switch item.kind {
            case .proposal: String(appLocalized: "Proposal")
            case .vote: String(appLocalized: "Vote")
            case .speech: String(appLocalized: "Speech")
            }
        return [kind, item.proposition, Self.shortDay(item.date)].compactMap(\.self)
            .joined(separator: " · ")
    }

    public func highlightKicker(_ highlight: Highlight) -> String {
        let kind =
            switch highlight.kind {
            case .action: String(appLocalized: "Proposal")
            case .vote: String(appLocalized: "Vote")
            case .money: String(appLocalized: "Money")
            case .indicator: String(appLocalized: "Indicator")
            }
        return "\(kind) · \(Self.shortDay(highlight.date))"
    }

    public var highlightScope: String {
        activity.highlightsAreNational
            ? String(appLocalized: "Brazil")
            : place?.name ?? representatives?.name ?? ""
    }

    public func route(for highlight: Highlight) -> Route? {
        switch highlight.kind {
        case .action: .person(slug: highlight.route)
        case .vote: .vote(id: highlight.route)
        case .money, .indicator: nil
        }
    }

    public func highlightAccessibility(_ highlight: Highlight) -> String {
        let person = highlight.person.map { "\($0.name), \($0.party)." }
        let relevance = Relevance(weight: highlight.weight).title
        return [
            highlightKicker(highlight), person, highlight.title, highlight.subtitle,
            String(appLocalized: "\(relevance), weight \(highlight.weight) of 100."),
        ]
        .compactMap(\.self).joined(separator: " ")
    }

    public func voteAccessibility(_ vote: MineVote) -> String {
        let board = vote.board
        return "\(board.accessibilityText) \(vote.heading): \(vote.countsText)."
    }

    public func seatAccessibility(_ seat: MineSeat) -> String {
        let card = seat.holder
        return [
            seat.title, card.name, card.party, card.officeTitle, mandateText(for: card),
            status(of: card),
        ]
        .compactMap(\.self).joined(separator: ", ")
    }

    public var activitySource: String? { SourceFootnote.text(activity.sources) }

    public static let shortNameLimit = 14

    static func shortName(_ name: String) -> String {
        guard name.count > shortNameLimit else { return name }
        return name.split(separator: " ").first.map(String.init) ?? name
    }

    static func shortDay(_ day: CalendarDay) -> String {
        day.date().formatted(.dateTime.day(.twoDigits).month(.twoDigits).locale(.app))
    }

    static func current(_ people: [PersonCard]) -> [PersonCard] {
        alphabetical(people.filter { $0.status != .electedAwaiting })
    }

    static func awaiting(_ people: [PersonCard]) -> [PersonCard] {
        alphabetical(people.filter { $0.status == .electedAwaiting })
    }

    static func seat(
        _ level: MineSeat.Level, place: String, holder: Office, vice: Office,
        in groups: [RepresentativeGroup]
    ) -> MineSeat? {
        let holders = groups.filter { $0.office == holder }.flatMap(\.people)
        let vices = groups.filter { $0.office == vice }.flatMap(\.people)
        let sitting = current(holders)
        let elected = awaiting(holders)
        guard let first = sitting.first ?? elected.first else { return nil }
        return MineSeat(
            level: level, place: place, holder: first,
            vice: current(vices).first ?? (sitting.isEmpty ? awaiting(vices).first : nil),
            elected: elected.filter { $0.slug != first.slug })
    }

    static func bench(
        _ office: Office, title: String, place: String, in groups: [RepresentativeGroup]
    ) -> MineBench? {
        let matching = groups.filter { $0.office == office }
        let people = matching.flatMap(\.people)
        let sitting = current(people)
        let elected = awaiting(people)
        let members = sitting.isEmpty ? elected : sitting
        guard !members.isEmpty else { return nil }
        let label =
            matching.first { group in group.people.contains { $0.status != .electedAwaiting } }?
            .title ?? matching.first?.title ?? office.title
        return MineBench(
            office: office, title: title, subtitle: "\(label) · \(place)", members: members,
            elected: sitting.isEmpty ? [] : elected)
    }
}
