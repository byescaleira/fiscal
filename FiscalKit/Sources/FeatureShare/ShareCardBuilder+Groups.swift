import FiscalDomain
import Foundation

extension ShareCardBuilder {
    public func race(_ race: Race) -> ShareCardContent {
        let candidates = race.candidates.sorted { $0.votes > $1.votes }.map { candidate in
            ShareRace.Candidate(
                number: candidate.number, name: candidate.name, party: candidate.party,
                percent: RaceText.shortPercent(candidate.percent),
                share: min(max(candidate.percent / 100, 0), 1),
                votes: RaceText.votes(candidate.votes),
                elected: race.final && candidate.elected)
        }
        let footnote = String(
            appLocalized:
                "Blank \(RaceText.votes(race.votes.blank)) · Null \(RaceText.votes(race.votes.null))"
        )
        let body = ShareRace(
            counted: String(
                appLocalized: "Polling stations counted: \(RaceText.percent(race.sections.percent))"
            ),
            countedShare: min(max(race.sections.percent / 100, 0), 1), candidates: candidates,
            footnote: footnote)
        return ShareCardContent(
            eyebrow: eyebrow(
                String(appLocalized: "Vote count"), String(appLocalized: "Round \(race.round)")),
            headline: RaceText.title(office: race.office, uf: race.uf), faces: [],
            body: .race(body),
            source: sourceLine(
                name: String(appLocalized: "Superior Electoral Court"), updatedAt: race.generatedAt),
            stamp: stamp(origin: "tse", "APU", race.id, race.generatedAt),
            link: link("race", race.id))
    }

    public func compare(_ profiles: [Profile]) -> ShareCardContent {
        let rows: [ShareCompareRow] = [
            ShareCompareRow(
                label: String(appLocalized: "Attendance"),
                values: profiles.map { PublicFormat.percent($0.numbers.attendance?.fraction) }),
            ShareCompareRow(
                label: String(appLocalized: "Roll-call votes"),
                values: profiles.map { PublicFormat.number($0.numbers.votes) }),
            ShareCompareRow(
                label: String(appLocalized: "Bills filed"),
                values: profiles.map { PublicFormat.number($0.numbers.proposals) }),
            ShareCompareRow(
                label: String(appLocalized: "Office allowance used"),
                values: profiles.map { PublicFormat.compactMoney(cents: $0.numbers.quotaCents) }),
            ShareCompareRow(
                label: String(appLocalized: "Declared assets"),
                values: profiles.map { PublicFormat.compactMoney(cents: $0.numbers.assetsCents) }),
        ]
        let sources = profiles.compactMap { primarySource($0.sources, for: $0.office) }
        var unique: [Source] = []
        for source in sources where !unique.contains(where: { $0.id == source.id }) {
            unique.append(source)
        }
        let names = unique.map(\.name).joined(separator: ", ")
        let updated = unique.compactMap(\.updatedAt).max()
        let slugs = profiles.map(\.slug).joined(separator: ",")
        return ShareCardContent(
            eyebrow: eyebrow(String(appLocalized: "Side by side")), headline: nil,
            faces: profiles.map(face), body: .compare(rows),
            source: sourceLine(
                name: names.isEmpty ? PublicFormat.missing : names, updatedAt: updated),
            stamp: stamp(origin: unique.first?.id ?? "fiscal", "CMP", slugs, updated),
            link: link("compare", slugs))
    }

    public func representatives(_ place: PlaceRepresentatives) -> ShareCardContent {
        let groups = place.groups.filter { !$0.people.isEmpty }.map { group in
            let names = group.people.map(\.name).sorted {
                $0.localizedStandardCompare($1) == .orderedAscending
            }
            return ShareGroup(
                title: group.title, count: PublicFormat.number(group.people.count),
                names: names.count <= 3 ? names : [])
        }
        let source = place.sources.first
        return ShareCardContent(
            eyebrow: eyebrow(String(appLocalized: "Who represents"), uf(place.uf)),
            headline: place.name, faces: [], body: .representatives(groups),
            source: sourceLine(source),
            stamp: stamp(source, "REP", place.uf, source?.updatedAt),
            link: link("place", place.uf))
    }
}
