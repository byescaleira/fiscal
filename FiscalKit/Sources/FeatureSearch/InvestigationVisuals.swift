import Charts
import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct PeerStripVisual: View {
    static let padding = 0.15

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.liteMode) private var liteMode
    @State private var isShown = false
    let strip: InvestigationLink.PeerStrip

    private var reduceMotion: Bool { systemReduceMotion || liteMode.reducesMotion }

    var body: some View {
        let entry = strip.entry
        let low = min(entry.p25 ?? entry.median, entry.value, entry.median)
        let high = max(entry.p75 ?? entry.median, entry.value, entry.median)
        let pad = max((high - low) * Self.padding, entry.median * Self.padding, 1)
        VStack(alignment: .leading, spacing: .spaceS) {
            HStack(alignment: .firstTextBaseline, spacing: .spaceS) {
                Text(verbatim: strip.value)
                    .font(.caseNumber)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(.shareTextShrink)
                PeerBadge(band: entry.band)
            }
            Chart {
                if let p25 = entry.p25, let p75 = entry.p75 {
                    RectangleMark(
                        xStart: .value("p25", p25), xEnd: .value("p75", p75),
                        y: .value("Band", "peers"), height: .fixed(.caseStrip)
                    )
                    .foregroundStyle(Color.secondary.opacity(.opacityCaseBand))
                    .cornerRadius(.caseStrip / 2)
                }
                RuleMark(x: .value("Median", entry.median))
                    .foregroundStyle(Color.secondary)
                    .lineStyle(.chartAverage)
                PointMark(
                    x: .value("Value", isShown ? entry.value : entry.median),
                    y: .value("Band", "peers")
                )
                .symbolSize(.caseStripDot * .caseStripDot)
                .foregroundStyle(entry.band.color)
            }
            .chartXScale(domain: (low - pad)...(high + pad))
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .frame(height: .caseStrip + .spaceS)
            .accessibilityLabel(Text(verbatim: strip.metric.title))
            .accessibilityValue(Text(verbatim: "\(strip.value). \(strip.median)"))
            HStack(spacing: .spaceS) {
                Label(strip.median, systemImage: "line.diagonal")
                Spacer(minLength: .spaceS)
                if let p25 = entry.p25, let p75 = entry.p75 {
                    Text(
                        "Average band: \(strip.metric.format(p25)) to \(strip.metric.format(p75))"
                    )
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            Text(verbatim: strip.metric.direction)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .smooth(duration: 1)) { isShown = true }
        }
    }
}

struct PairVisual: View {
    let faces: [PersonCard]
    let rows: [InvestigationLink.PairRow]

    var body: some View {
        VStack(spacing: .spaceM) {
            HStack {
                ForEach(Array(faces.prefix(2).enumerated()), id: \.element.id) { index, card in
                    if index == 1 { Spacer(minLength: .spaceS) }
                    VStack(alignment: index == 0 ? .leading : .trailing, spacing: .space2XS) {
                        PersonPortrait(
                            slug: card.slug, name: card.name, party: card.party, size: .badgeL)
                        PartyMark(card.party)
                    }
                }
            }
            ForEach(rows) { row in
                VStack(spacing: .space2XS) {
                    Text(verbatim: row.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline) {
                        Text(verbatim: row.values.first ?? PublicFormat.missing)
                        Spacer(minLength: .spaceS)
                        Text(verbatim: row.values.last ?? PublicFormat.missing)
                    }
                    .font(.amountRow)
                    .monospacedDigit()
                    HStack(spacing: .caseMirror) {
                        ShareBarChart(value: row.shares.first ?? 0, color: color(0), mirrored: true)
                        ShareBarChart(value: row.shares.last ?? 0, color: color(1))
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func color(_ index: Int) -> Color {
        guard faces.indices.contains(index) else { return .secondary }
        let palette = PartyPalette.of(party: faces[index].party)
        let same = faces.count == 2 && faces[0].party == faces[1].party
        return same && index == 1 ? palette.secondary : palette.primary
    }
}

struct CountsVisual: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let counts: [InvestigationLink.Count]

    var body: some View {
        if !counts.isEmpty {
            let layout =
                dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: .spaceM))
                : AnyLayout(HStackLayout(alignment: .top, spacing: .spaceXL))
            layout {
                ForEach(counts) { count in
                    VStack(alignment: .leading, spacing: .zero) {
                        Text(verbatim: count.value)
                            .font(.caseNumber)
                            .monospacedDigit()
                        Text(verbatim: count.label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

struct ChecksVisual: View {
    let lines: [InvestigationLink.CheckLine]

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceM) {
            ForEach(lines) { line in
                Link(destination: line.url) {
                    HStack(alignment: .top, spacing: .spaceS) {
                        StatusCircle(
                            line.verdict ?? String(appLocalized: "No label"),
                            symbol: "checkmark.shield", color: .secondary,
                            isDashed: line.verdict == nil)
                        VStack(alignment: .leading, spacing: .space2XS) {
                            Text(
                                verbatim: [line.verdict, line.date].compactMap(\.self).joined(
                                    separator: " · ")
                            )
                            .font(.caseKicker)
                            .foregroundStyle(.secondary)
                            Text(verbatim: line.title)
                                .font(.subheadline)
                                .foregroundStyle(Color.primary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }
}

struct HighlightVisual: View {
    let ref: HighlightRef

    var body: some View {
        HStack(alignment: .top, spacing: .spaceM) {
            Rectangle()
                .fill(Color.retroTeal)
                .frame(width: .space2XS)
                .clipShape(.capsule)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: .spaceS) {
                Text(verbatim: "“\(ref.title)”")
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: .spaceS) {
                    RelevanceBadge(weight: ref.weight)
                    Text(verbatim: ref.dayText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct ChangeVisual: View {
    let before: Double?
    let during: Double?
    let months: Int

    var body: some View {
        HStack(alignment: .top, spacing: .spaceL) {
            column(title: String(appLocalized: "Before"), value: before)
            Image(systemName: "arrow.right")
                .font(.emphasis(.title3, weight: .semibold))
                .foregroundStyle(.tertiary)
                .padding(.top, .spaceM)
                .accessibilityHidden(true)
            column(title: String(appLocalized: "During"), value: during)
        }
    }

    private func column(title: String, value: Double?) -> some View {
        VStack(alignment: .leading, spacing: .zero) {
            Text(verbatim: InvestigationLink.Visual.changeColumn(title, months: months))
                .font(.caseKicker)
                .foregroundStyle(.secondary)
            Text(verbatim: PublicFormat.percent(value))
                .font(.caseNumber)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct ResultsVisual: View {
    let approved: Int
    let rejected: Int
    let votes: [VoteSummary]

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceM) {
            HStack(spacing: .spaceL) {
                HStack(spacing: .spaceS) {
                    StatusCircle(
                        String(appLocalized: "Approved"), symbol: "checkmark", color: .voteYes)
                    Text(verbatim: PublicFormat.number(approved)).font(.caseNumber)
                        .monospacedDigit()
                }
                HStack(spacing: .spaceS) {
                    StatusCircle(String(appLocalized: "Rejected"), symbol: "xmark", color: .voteNo)
                    Text(verbatim: PublicFormat.number(rejected)).font(.caseNumber)
                        .monospacedDigit()
                }
            }
            ForEach(votes) { vote in
                RouteLink(.vote(id: vote.id)) {
                    VStack(alignment: .leading, spacing: .spaceHairline) {
                        Text(verbatim: "\(vote.heading) · \(vote.house.title)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(verbatim: vote.plainSummary ?? vote.summary)
                            .font(.subheadline)
                            .foregroundStyle(Color.primary)
                            .lineLimit(2)
                        SameDayVotesMark(vote: vote)
                    }
                }
            }
        }
    }
}
