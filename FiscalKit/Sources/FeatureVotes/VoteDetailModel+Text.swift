import FeatureCore
import FiscalDomain
import Foundation

extension VoteDetailModel {
    public static let amendmentShare = 3.0 / 5.0

    public var title: String { vote?.proposition ?? String(appLocalized: "Vote") }

    public var heroCaption: String {
        guard let vote else { return "" }
        let date = vote.date.date().formatted(
            Date.FormatStyle(locale: .app).day(.twoDigits).month(.twoDigits))
        return [String(appLocalized: "Floor"), VotesModel.shortHouse(vote.house), date, vote.time]
            .compactMap(\.self).joined(separator: " · ").uppercased(with: .app)
    }

    public var yesText: String { PublicFormat.number(vote?.yes) }

    public var noText: String { PublicFormat.number(vote?.no) }

    public var yesValue: Double { Double(vote?.yes ?? 0) }

    public var noValue: Double { Double(vote?.no ?? 0) }

    public var othersText: String {
        String(appLocalized: "\(PublicFormat.number(vote?.others)) other votes")
    }

    public var quorumText: String {
        String(appLocalized: "Quorum \(PublicFormat.number(detail?.quorum))")
    }

    public var votersText: String {
        String(appLocalized: "\(PublicFormat.number(vote?.tally.total)) voted")
    }

    public var isAmendment: Bool {
        guard let vote else { return false }
        let kind = VoteDetailModel.fold(vote.kind ?? "")
        return vote.proposition.uppercased().hasPrefix("PEC")
            || kind.contains("emenda a constituicao")
    }

    public var requiredYes: Int? {
        guard let vote, isAmendment else { return nil }
        let seats = vote.house == .camara ? 513 : 81
        return Int((Double(seats) * Self.amendmentShare).rounded(.up))
    }

    public var headline: String {
        guard let vote, let outcome else { return PublicFormat.missing }
        switch outcome {
        case .approved, .rejected:
            if let required = requiredYes {
                return String(
                    appLocalized:
                        "\(outcome.title) · a constitutional amendment needs \(PublicFormat.number(required)) yes votes"
                )
            }
            return String(
                appLocalized:
                    "\(outcome.title) by \(PublicFormat.number(vote.yes)) to \(PublicFormat.number(vote.no))"
            )
        case .symbolic:
            return String(appLocalized: "Voice vote: no one's name is recorded")
        case .pending:
            return String(appLocalized: "The house hasn't published the result yet")
        }
    }

    public var accessibilityScore: String {
        guard let vote else { return "" }
        return [
            heroCaption, outcome?.title, VoteTally.label(vote.tally), quorumText, headline,
        ]
        .compactMap(\.self).joined(separator: ". ")
    }

    public var plainSummary: String? { vote?.plainSummary }

    public var officialSummary: String { vote?.summary ?? PublicFormat.missing }

    public var kindText: String? { vote?.kind }

    public var sourceText: String {
        let sources = detail?.sources ?? []
        guard !sources.isEmpty else { return String(appLocalized: "Source: —") }
        return sources.map { source in
            guard let updated = source.updatedAt else {
                return String(appLocalized: "Source: \(source.name)")
            }
            let time = updated.formatted(
                Date.FormatStyle(locale: .app).day(.twoDigits).month(.twoDigits).hour().minute())
            return String(appLocalized: "Source: \(source.name) · updated \(time)")
        }
        .joined(separator: "\n")
    }

    public func partyAccessibility(_ row: PartyRow) -> String {
        let counts = BallotChoice.allCases.map { "\($0.groupTitle) \(row.count($0))" }
        return ([row.party] + counts).joined(separator: ", ")
    }

    public func ballotDetail(_ ballot: VoteDetail.Ballot) -> String {
        "\(ballot.party) · \(ballot.uf.uppercased())"
    }

    public func ballotAccessibility(_ ballot: VoteDetail.Ballot) -> String {
        "\(ballot.name), \(ballotDetail(ballot)), \(ballot.vote)"
    }

    public var representativesTitle: String {
        String(appLocalized: "Your Representatives · \((homeUF ?? "").uppercased())")
    }

    public var ballotsTitle: String {
        String(appLocalized: "Roll Call · \(PublicFormat.number(detail?.people.count))")
    }

    public var ballotsEmptyText: String {
        if detail?.people.isEmpty ?? true {
            return String(
                appLocalized: "This vote has no names: the house didn't publish who voted how.")
        }
        return String(appLocalized: "No one matches this search.")
    }

    public func filterTitle(_ filter: BallotFilter) -> String {
        "\(filter.title) \(count(filter))"
    }
}
