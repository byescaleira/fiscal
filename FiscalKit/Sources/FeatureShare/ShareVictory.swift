import FiscalDomain
import Foundation

public struct ShareVictory: Hashable, Sendable {
    public struct Runner: Hashable, Sendable {
        public let face: ShareFace
        public let percent: String
    }

    public struct Ballot: Hashable, Sendable, Identifiable {
        public enum Kind: String, Hashable, Sendable {
            case valid, blank, null
        }

        public let kind: Kind
        public let title: String
        public let percent: String
        public let share: Double

        public var id: String { kind.rawValue }
    }

    public let winner: ShareFace
    public let percent: String
    public let statement: String
    public let runnerUp: Runner?
    public let ballots: [Ballot]
    public let context: String

    public var texts: [String] {
        [winner.name, winner.party, String(appLocalized: "Elected"), percent, statement]
            + (runnerUp.map { [$0.face.name, $0.face.party, $0.percent] } ?? [])
            + ballots.flatMap { [$0.title, $0.percent] } + [context]
    }
}

extension ShareCardContent {
    public var victory: ShareVictory? {
        if case .victory(let victory) = body { return victory }
        return nil
    }

    public var isVictory: Bool { victory != nil }
}

extension ShareCard {
    public var victory: ShareVictory? { content.victory }
}

extension ShareCardBuilder {
    func victory(_ race: Race, winner: RaceCandidate) -> ShareCardContent {
        let percent = RaceText.percent(winner.percent)
        let runner = race.candidates.filter { $0.number != winner.number }
            .max { $0.votes < $1.votes }
        let title = RaceText.title(office: race.office, uf: race.uf)
        let result =
            race.generatedAt.map {
                String(appLocalized: "Final TSE result at \(RaceText.time($0))")
            } ?? String(appLocalized: "Final TSE result")
        let context = [
            RaceText.office(race.office), RaceText.scope(race.uf),
            String(appLocalized: "Round \(race.round)"), result,
        ].joined(separator: " · ")
        let body = ShareVictory(
            winner: face(winner, title: title), percent: percent,
            statement: String(appLocalized: "Elected with \(percent) of the valid votes"),
            runnerUp: runner.map {
                ShareVictory.Runner(
                    face: face($0, title: title), percent: RaceText.percent($0.percent))
            },
            ballots: ballots(race.votes), context: context)
        return ShareCardContent(
            eyebrow: eyebrow(
                String(appLocalized: "Final result"), String(appLocalized: "Round \(race.round)")),
            headline: title, faces: [body.winner], body: .victory(body),
            source: sourceLine(
                name: String(appLocalized: "Superior Electoral Court"), updatedAt: race.generatedAt),
            stamp: stamp(origin: "tse", "ELE", race.id, race.generatedAt),
            link: link("race", race.id))
    }

    func face(_ candidate: RaceCandidate, title: String) -> ShareFace {
        ShareFace(
            slug: candidate.portraitSlug, name: candidate.name, party: candidate.party,
            detail: title)
    }

    func ballots(_ votes: Race.Votes) -> [ShareVictory.Ballot] {
        guard votes.total > 0 else { return [] }
        let parts: [(ShareVictory.Ballot.Kind, String, Int)] = [
            (.valid, String(appLocalized: "Valid"), votes.valid),
            (.blank, String(appLocalized: "Blank"), votes.blank),
            (.null, String(appLocalized: "Null"), votes.null),
        ]
        return parts.map { kind, title, count in
            let share = Double(count) / Double(votes.total)
            return ShareVictory.Ballot(
                kind: kind, title: title, percent: RaceText.shortPercent(share * 100),
                share: share)
        }
    }
}
