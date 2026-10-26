import FiscalDomain
import Foundation

extension ShareCardBuilder {
    public func highlight(
        _ highlight: Highlight, vote: VoteDetail?, stage: String?, sources: [Source]
    ) -> ShareCardContent {
        let house = house(of: highlight, vote: vote)
        let source = source(vote: vote, house: house, sources: sources)
        let body = ShareHighlight(
            title: highlight.title, person: highlight.person.map(face),
            place: place(highlight, house: house, vote: vote, stage: stage),
            tally: vote.map(tally),
            weight: String(
                appLocalized: "Weight \(highlight.weight) of 100 · repercussion + impact"),
            uncertainty: highlight.coverage.uncertainty)
        return ShareCardContent(
            eyebrow: eyebrow(
                String(appLocalized: "Highlight of the Moment"), kind(highlight.kind),
                dayMonth(highlight.date)),
            headline: nil, faces: highlight.person.map { [face($0)] } ?? [],
            body: .highlight(body), source: sourceLine(source),
            stamp: stamp(source, "DST", highlight.id, highlight.date.date(in: calendar)),
            link: link("highlight", highlight.id))
    }

    func face(_ card: PersonCard) -> ShareFace {
        ShareFace(
            slug: card.slug, name: card.name, party: card.party,
            detail: [uf(card.uf), card.office.title].joined(separator: " · "))
    }

    func kind(_ kind: Highlight.Kind) -> String {
        switch kind {
        case .action: String(appLocalized: "Proposal")
        case .vote: String(appLocalized: "Vote")
        case .money: String(appLocalized: "Money")
        case .indicator: String(appLocalized: "Indicator")
        }
    }

    func house(of highlight: Highlight, vote: VoteDetail?) -> House? {
        if let vote { return vote.vote.house }
        switch highlight.person?.office {
        case .senator: return .senado
        case .federalDeputy: return .camara
        default: return nil
        }
    }

    func source(vote: VoteDetail?, house: House?, sources: [Source]) -> Source? {
        if let vote {
            return vote.sources.first { $0.id == vote.vote.house.rawValue } ?? vote.sources.first
        }
        let houses = house.map { [$0.rawValue] } ?? House.allCases.map(\.rawValue)
        return sources.first { houses.contains($0.id) } ?? sources.first
    }

    func place(_ highlight: Highlight, house: House?, vote: VoteDetail?, stage: String?)
        -> String
    {
        let name: String? =
            switch house {
            case .senado: String(appLocalized: "Senate")
            case .camara: String(appLocalized: "Chamber")
            case nil: nil
            }
        let status = vote.flatMap { result($0.vote) } ?? stage
        let parts = [name, highlight.proposition, status].compactMap(\.self)
            .filter { !$0.isEmpty }
        return parts.isEmpty ? highlight.subtitle : parts.joined(separator: " · ")
    }
}
