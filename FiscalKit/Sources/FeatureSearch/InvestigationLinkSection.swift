import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct LinkSection: View {
    let link: InvestigationLink

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: .spaceM) {
                LinkThread(ids: link.pieces)
                Text(verbatim: link.sentence)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                LinkVisual(visual: link.visual)
            }
            .padding(.vertical, .spaceXS)
            .accessibilityElement(children: .combine)
            if let route = link.route {
                RouteLink(route) {
                    Text("See the official data")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primary)
                }
            }
        } header: {
            Text(verbatim: link.question).sectionTitle().textCase(nil)
        } footer: {
            VStack(alignment: .leading, spacing: .space2XS) {
                if let uncertainty = link.uncertainty {
                    Label(uncertainty, systemImage: "questionmark.circle")
                }
                if let source = link.source {
                    Text(verbatim: source)
                }
            }
        }
    }
}

private struct LinkThread: View {
    @Environment(InvestigationModel.self) private var board
    let ids: [String]

    var body: some View {
        let pieces = ids.compactMap { id in board.pieces.first { $0.id == id } }
        if pieces.count > 1 {
            HStack(spacing: .space2XS) {
                ForEach(pieces) { piece in
                    HStack(spacing: .space2XS) {
                        StatusCircle(
                            piece.kind.title, symbol: piece.symbol, color: piece.kind.color)
                        Text(verbatim: piece.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    if piece.id != pieces.last?.id {
                        Capsule()
                            .fill(Color.secondary.opacity(.opacitySoft))
                            .frame(width: .spaceL, height: .caseThread)
                            .accessibilityHidden(true)
                    }
                }
            }
            .accessibilityHidden(true)
        }
    }
}

struct LinkVisual: View {
    let visual: InvestigationLink.Visual

    var body: some View {
        switch visual {
        case .ballot(let choice, let vote, let guidance, let followed):
            BallotVisual(choice: choice, vote: vote, guidance: guidance, followed: followed)
        case .delegation(let counts, let diverged):
            DelegationVisual(counts: counts, diverged: diverged)
        case .peer(let strip):
            PeerStripVisual(strip: strip)
        case .guidance(let guidance):
            GuidanceVisual(guidance: guidance)
        case .pair(let faces, let rows):
            PairVisual(faces: faces, rows: rows)
        case .counts(let counts):
            CountsVisual(counts: counts)
        case .checks(let lines, _):
            ChecksVisual(lines: lines)
        case .highlight(let ref):
            HighlightVisual(ref: ref)
        case .change(let before, let during, _, let months):
            ChangeVisual(before: before, during: during, months: months)
        case .results(let approved, let rejected, let votes):
            ResultsVisual(approved: approved, rejected: rejected, votes: votes)
        }
    }
}

private struct BallotVisual: View {
    let choice: BallotChoice?
    let vote: String
    let guidance: String?
    let followed: Bool?

    var body: some View {
        AdaptiveStack(spacing: .spaceL) {
            HStack(spacing: .spaceS) {
                BallotChip(vote, choice: choice)
                VStack(alignment: .leading, spacing: .zero) {
                    Text("Vote").font(.caseKicker).foregroundStyle(.secondary)
                    Text(verbatim: choice?.title ?? vote).font(.amountRow)
                }
            }
            if let guidance {
                let guided = BallotChoice(vote: guidance)
                HStack(spacing: .spaceS) {
                    StatusCircle(
                        guidance, symbol: guided?.symbol ?? "flag",
                        color: guided?.color ?? .secondary)
                    VStack(alignment: .leading, spacing: .zero) {
                        Text("Party guidance").font(.caseKicker).foregroundStyle(.secondary)
                        Text(verbatim: guidance).font(.amountRow)
                    }
                }
            }
            if let followed {
                HStack(spacing: .spaceS) {
                    StatusCircle(
                        followed
                            ? String(appLocalized: "Same as the guidance")
                            : String(appLocalized: "Different from the guidance"),
                        symbol: followed ? "equal" : "arrow.left.arrow.right", color: .retroDenim)
                    Text(followed ? "Same as the guidance" : "Different from the guidance")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct DelegationVisual: View {
    let counts: [BallotChoice: Int]
    let diverged: [VoteDetail.Ballot]

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceM) {
            TallyChart(
                segments: BallotChoice.allCases.map { choice in
                    TallyChart.Segment(
                        id: choice.rawValue, title: choice.title,
                        value: Double(counts[choice] ?? 0), color: choice.color,
                        dashed: choice == .absent)
                })
            FlowLayout(spacing: .spaceM) {
                ForEach(BallotChoice.allCases) { choice in
                    if let count = counts[choice], count > 0 {
                        HStack(spacing: .space2XS) {
                            BallotChip(choice)
                            Text(verbatim: "\(PublicFormat.number(count)) \(choice.title)")
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                        }
                    }
                }
            }
            if !diverged.isEmpty {
                DivergedPile(ballots: diverged)
            }
        }
    }
}

private struct DivergedPile: View {
    static let faceLimit = 8
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let ballots: [VoteDetail.Ballot]

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            Text("Voted differently from their party")
                .font(.caseKicker)
                .foregroundStyle(.secondary)
            if !dynamicTypeSize.isAccessibilitySize {
                HStack(spacing: .regionFaceOverlap) {
                    ForEach(ballots.prefix(Self.faceLimit)) { ballot in
                        PersonPortrait(
                            slug: ballot.slug ?? ballot.id, name: ballot.name, party: ballot.party,
                            size: .badgeM
                        )
                        .overlay {
                            Circle().strokeBorder(Color.plainRow, lineWidth: .spaceHairline)
                        }
                    }
                }
                .accessibilityHidden(true)
            }
            Text(verbatim: names)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var names: String {
        let shown = ballots.prefix(Self.faceLimit).map {
            "\($0.name) (\($0.party)-\($0.uf.uppercased()))"
        }
        let rest = ballots.count - shown.count
        let list = shown.formatted(.list(type: .and).locale(.app))
        return rest > 0 ? String(appLocalized: "\(list) and \(rest) more") : list
    }
}

private struct GuidanceVisual: View {
    let guidance: PersonFacts.Guidance

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceM) {
            HStack(alignment: .firstTextBaseline, spacing: .spaceS) {
                Text(verbatim: PublicFormat.number(guidance.followed))
                    .font(.caseNumber)
                    .monospacedDigit()
                Text("of \(guidance.total) like the party's guidance")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            TallyChart(
                segments: [
                    TallyChart.Segment(
                        id: "followed", title: String(appLocalized: "Like the party"),
                        value: Double(guidance.followed), color: ChartPalette.color(at: 0)),
                    TallyChart.Segment(
                        id: "against", title: String(appLocalized: "Against the party"),
                        value: Double(guidance.against), color: ChartPalette.color(at: 1)),
                    TallyChart.Segment(
                        id: "other", title: String(appLocalized: "Abstained or other"),
                        value: Double(guidance.other), color: .secondary, dashed: true),
                ])
            FlowLayout(spacing: .spaceM) {
                GuidanceKey(
                    title: String(appLocalized: "Like the party"), count: guidance.followed,
                    symbol: "equal", color: ChartPalette.color(at: 0))
                GuidanceKey(
                    title: String(appLocalized: "Against the party"), count: guidance.against,
                    symbol: "arrow.left.arrow.right", color: ChartPalette.color(at: 1))
                GuidanceKey(
                    title: String(appLocalized: "Abstained or other"), count: guidance.other,
                    symbol: "minus", color: .secondary)
            }
        }
    }
}

private struct GuidanceKey: View {
    let title: String
    let count: Int
    let symbol: String
    let color: Color

    var body: some View {
        HStack(spacing: .space2XS) {
            StatusCircle(title, symbol: symbol, color: color)
            Text(verbatim: "\(PublicFormat.number(count)) · \(title)")
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
        }
    }
}
