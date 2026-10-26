import FeatureCore
import FiscalDomain
import Foundation

struct InvestigationLinks {
    let pieces: [InvestigationPiece]
    let evidence: InvestigationEvidence

    func board() -> InvestigationBoard {
        var links: [InvestigationLink] = []
        let people = pieces.people
        for vote in pieces.votes {
            links += voteLinks(vote, people: people)
        }
        for card in people {
            links += personLinks(card)
        }
        if people.count >= 2, let pair = pair(people[0], people[1]) { links.append(pair) }
        if people.isEmpty {
            for theme in pieces.themes { links.append(themeVotes(theme)) }
        }
        var notes: [String] = []
        if evidence.isPartial {
            notes.append(
                String(
                    appLocalized: "Some pieces couldn't load; the reading uses only what loaded."))
        }
        return InvestigationBoard(
            links: links, notes: notes, hints: hints(links: links), sources: sources(),
            updatedAt: evidence.updatedAt)
    }

    private func hints(links: [InvestigationLink]) -> [String] {
        var hints: [String] = []
        let hasPeople = !pieces.people.isEmpty
        if pieces.votes.isEmpty, !pieces.places.isEmpty || !pieces.parties.isEmpty || hasPeople {
            hints.append(String(appLocalized: "Add a vote to see how each piece voted."))
        }
        if !hasPeople, pieces.votes.isEmpty, pieces.themes.isEmpty {
            hints.append(
                String(appLocalized: "Add a person to see attendance, spending and votes."))
        }
        if links.isEmpty, hints.isEmpty {
            hints.append(
                String(appLocalized: "These pieces don't connect yet. Add a person or a vote."))
        }
        return hints
    }

    private func sources() -> [Source] {
        var seen = Set<String>()
        let all =
            evidence.votes.values.flatMap(\.sources) + evidence.profiles.values.flatMap(\.sources)
            + evidence.checks.values.flatMap(\.sources)
            + evidence.contexts.values.flatMap(\.sources)
            + (evidence.facts?.sources ?? [])
        return all.filter { seen.insert($0.id).inserted }
    }

    func houseSource(_ detail: VoteDetail) -> String {
        let name = detail.sources.first { $0.id == detail.vote.house.rawValue }?.name
        return String(appLocalized: "Source: \(name ?? detail.vote.house.title)")
    }

    static func guidance(in detail: VoteDetail, party: String) -> String? {
        let target = SearchText.fold(party).trimmingCharacters(in: .whitespaces)
        guard !target.isEmpty else { return nil }
        return detail.guidance.first { item in
            SearchText.words(item.party).contains(target)
                || SearchText.fold(item.party).trimmingCharacters(in: .whitespaces) == target
        }?.guidance
    }

    static func diverges(_ ballot: VoteDetail.Ballot, in detail: VoteDetail) -> Bool {
        guard
            let guidance = guidance(in: detail, party: ballot.party).flatMap(
                BallotChoice.init(vote:)),
            guidance == .yes || guidance == .no,
            let choice = BallotChoice(vote: ballot.vote), choice == .yes || choice == .no
        else { return false }
        return guidance != choice
    }
}

extension InvestigationLinks {
    func voteLinks(_ vote: VoteSummary, people: [PersonCard]) -> [InvestigationLink] {
        guard let detail = evidence.votes[vote.id] else { return [] }
        var links = people.map { ballot($0, detail: detail) }
        for place in pieces.places where place.isState {
            let group = detail.people.filter { $0.uf.lowercased() == place.uf.lowercased() }
            links.append(
                delegation(
                    detail, ballots: group, scope: place.name, id: "place-\(place.uf)",
                    piece: InvestigationPiece.place(place).id))
        }
        for party in pieces.parties {
            let group = detail.people.filter {
                SearchText.fold($0.party) == SearchText.fold(party)
            }
            links.append(
                delegation(
                    detail, ballots: group, scope: party, id: "party-\(party)",
                    piece: InvestigationPiece.party(party).id))
        }
        if people.isEmpty, pieces.places.isEmpty, pieces.parties.isEmpty {
            links.append(
                delegation(
                    detail, ballots: detail.people, scope: detail.vote.house.title, id: "house",
                    piece: nil))
        }
        return links
    }

    func ballot(_ card: PersonCard, detail: VoteDetail) -> InvestigationLink {
        let vote = detail.vote
        let pieceIDs = [InvestigationPiece.person(card).id, InvestigationPiece.vote(vote).id]
        let question = String(appLocalized: "How did \(card.name) vote?")
        guard let ballot = detail.people.first(where: { $0.slug == card.slug }) else {
            let votesHere =
                (vote.house == .camara && card.office == .federalDeputy)
                || (vote.house == .senado && card.office == .senator)
            let sentence =
                votesHere
                ? String(
                    appLocalized:
                        "\(card.name) doesn't appear in the roll call of \(vote.proposition).")
                : String(
                    appLocalized:
                        "\(card.name) doesn't vote in this house: \(vote.proposition) was voted in the \(vote.house.title)."
                )
            return InvestigationLink(
                id: "ballot-\(card.slug)-\(vote.id)", question: question, sentence: sentence,
                source: houseSource(detail), pieces: pieceIDs,
                visual: .ballot(
                    choice: nil, vote: PublicFormat.missing, guidance: nil, followed: nil),
                route: .vote(id: vote.id))
        }
        let choice = BallotChoice(vote: ballot.vote)
        let guidance = Self.guidance(in: detail, party: ballot.party)
        let guided = guidance.flatMap(BallotChoice.init(vote:))
        let followed: Bool? =
            if let guided, guided == .yes || guided == .no, let choice,
                choice == .yes || choice == .no
            {
                guided == choice
            } else {
                nil
            }
        var sentence = String(
            appLocalized: "\(card.name) voted \(ballot.vote) on \(vote.proposition).")
        if let guidance {
            sentence +=
                " "
                + String(appLocalized: "The guidance of \(ballot.party) was \(guidance).")
        }
        let uncertainty =
            detail.guidance.isEmpty
            ? String(
                appLocalized: "The \(vote.house.title) didn't publish party guidance for this vote."
            )
            : nil
        return InvestigationLink(
            id: "ballot-\(card.slug)-\(vote.id)", question: question, sentence: sentence,
            source: houseSource(detail), pieces: pieceIDs,
            visual: .ballot(
                choice: choice, vote: ballot.vote, guidance: guidance, followed: followed),
            compared: guidance == nil
                ? nil
                : String(appLocalized: "Each vote against the guidance of the person's own party"),
            uncertainty: uncertainty, route: .vote(id: vote.id))
    }

    func delegation(
        _ detail: VoteDetail, ballots: [VoteDetail.Ballot], scope: String, id: String,
        piece: String?
    ) -> InvestigationLink {
        var counts: [BallotChoice: Int] = [:]
        for ballot in ballots {
            counts[BallotChoice(vote: ballot.vote) ?? .abstain, default: 0] += 1
        }
        let diverged = ballots.filter { Self.diverges($0, in: detail) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        let vote = detail.vote
        let total = ballots.count
        var sentence = String(
            appLocalized:
                "\(scope) in \(vote.proposition): \(PublicFormat.number(counts[.yes] ?? 0)) Yes, \(PublicFormat.number(counts[.no] ?? 0)) No, \(PublicFormat.number(total - (counts[.yes] ?? 0) - (counts[.no] ?? 0))) other."
        )
        let hasGuidance = !detail.guidance.isEmpty
        if hasGuidance {
            sentence +=
                " "
                + String(
                    appLocalized:
                        "\(PublicFormat.number(diverged.count)) of \(PublicFormat.number(total)) voted differently from their own party's guidance."
                )
        }
        return InvestigationLink(
            id: "delegation-\(id)-\(vote.id)",
            question: String(appLocalized: "Who in \(scope) voted against their own party?"),
            sentence: sentence, source: houseSource(detail),
            pieces: [piece, InvestigationPiece.vote(vote).id].compactMap(\.self),
            visual: .delegation(counts: counts, diverged: diverged),
            keyNumber: hasGuidance && total > 0
                ? InvestigationSummary.KeyNumber(
                    value: "\(PublicFormat.number(diverged.count))/\(PublicFormat.number(total))",
                    label: String(appLocalized: "voted against their party's guidance"))
                : nil,
            compared: String(
                appLocalized: "Each vote against the guidance of the person's own party"),
            uncertainty: hasGuidance
                ? String(
                    appLocalized:
                        "Only Yes and No count as following or not; abstention and obstruction are left out."
                )
                : String(
                    appLocalized:
                        "The \(vote.house.title) didn't publish party guidance for this vote."),
            route: .vote(id: vote.id))
    }

    func themeVotes(_ theme: Theme) -> InvestigationLink {
        let votes = evidence.recent.filter { $0.themes.contains(theme) }
        let approved = votes.count { $0.approved == true }
        let rejected = votes.count { $0.approved == false }
        let sentence =
            votes.isEmpty
            ? String(appLocalized: "None of the votes in the latest update touched \(theme.title).")
            : String(
                appLocalized:
                    "In the latest update, \(PublicFormat.number(votes.count)) votes touched \(theme.title): \(PublicFormat.number(approved)) approved and \(PublicFormat.number(rejected)) rejected."
            )
        return InvestigationLink(
            id: "theme-\(theme.rawValue)",
            question: String(appLocalized: "What did Congress vote on \(theme.title)?"),
            sentence: sentence,
            source: String(appLocalized: "Source: Chamber of Deputies and Federal Senate"),
            pieces: [InvestigationPiece.theme(theme).id],
            visual: .results(approved: approved, rejected: rejected, votes: Array(votes.prefix(4))),
            keyNumber: votes.isEmpty
                ? nil
                : InvestigationSummary.KeyNumber(
                    value: PublicFormat.number(votes.count),
                    label: String(appLocalized: "votes on \(theme.title)")),
            uncertainty: String(
                appLocalized:
                    "Estimated: the topic comes from keywords in the official summary, and only the latest votes count."
            ))
    }
}
