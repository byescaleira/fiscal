import FiscalDomain
import Foundation

extension ProfileModel {
    public struct ThemeLine: Identifiable, Equatable {
        public let theme: Theme
        public let proposals: Int
        public let speeches: Int
        public let isLensTheme: Bool

        public var id: Theme { theme }
    }

    public struct BallotCount: Identifiable, Equatable {
        public let ballot: ProfileBallot
        public let count: Int

        public var id: String { ballot.title }
    }

    public var showsLensBadge: Bool { !lensThemes.isEmpty }

    public var lensThemes: [Theme] { lens?.themes ?? [] }

    public var isLensAdapted: Bool {
        guard let profile else { return false }
        return profile.themes.contains { lensThemes.contains($0.key) }
    }

    public var themeLines: [ThemeLine] {
        guard let profile else { return [] }
        let byTheme = Dictionary(
            profile.themes.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })
        let keys = profile.themes.map(\.key)
        let ordered = lensThemes.isEmpty ? keys : Lens(themes: lensThemes).ordered(keys)
        return ordered.compactMap { theme in
            byTheme[theme].map {
                ThemeLine(
                    theme: theme, proposals: $0.proposals, speeches: $0.speeches,
                    isLensTheme: lensThemes.contains(theme))
            }
        }
    }

    public func themeDetail(_ line: ThemeLine) -> String {
        let proposals = PublicFormat.number(line.proposals)
        let speeches = PublicFormat.number(line.speeches)
        return String(appLocalized: "Proposals: \(proposals) · Speeches: \(speeches)")
    }

    public var lensVotes: [PersonVote] {
        guard !lensThemes.isEmpty else { return [] }
        return (votes?.items ?? []).filter { vote in
            vote.themes.contains { lensThemes.contains($0) }
        }
    }

    public var lensBallots: [BallotCount] {
        let ballots = lensVotes.map { ProfileBallot($0.vote) }
        guard !ballots.isEmpty else { return [] }
        return ProfileBallot.tallied.map { ballot in
            BallotCount(ballot: ballot, count: ballots.filter { $0 == ballot }.count)
        }
    }

    public var lensVotesHeadline: String? {
        guard !lensVotes.isEmpty else { return nil }
        let count = PublicFormat.number(lensVotes.count)
        return String(appLocalized: "Recent votes in your themes: \(count)")
    }

    public var lensFootnote: String {
        let order =
            lensThemes.isEmpty
            ? String(
                appLocalized:
                    "Themes from the proposals and speeches, in the order the data comes. The numbers are the same for everyone."
            )
            : String(
                appLocalized:
                    "Your lens puts your themes first. The numbers are the same for everyone."
            )
        let estimate = String(
            appLocalized:
                "Estimated: each one's topic comes from keywords in its official summary and can miss."
        )
        return "\(order) \(estimate)"
    }
}
