import Charts
import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct MineBenchSection: View {
    let bench: MineBench

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: .spaceL) {
                MineBenchHeader(bench: bench)
                MineBenchChart(bench: bench)
                MineBenchLeaders(bench: bench)
            }
            .padding(.vertical, .spaceXS)
            NavigationLink {
                MineRosterScreen(roster: MineRoster(title: bench.title, people: bench.members))
            } label: {
                MineFacePile(bench: bench)
            }
            MineNextTermLink(bench: bench)
        } header: {
            Text(verbatim: bench.title).sectionTitle()
        }
    }
}

private struct MineBenchHeader: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let bench: MineBench

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: .spaceS) {
            Text(verbatim: PublicFormat.number(bench.total))
                .font(.scoreboardTitle)
                .monospacedDigit()
                .contentTransition(
                    reduceMotion ? .identity : .numericText(value: Double(bench.total)))
            Text(verbatim: bench.subtitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct MineBenchChart: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false
    @State private var position: Int?
    let bench: MineBench

    private var selected: MineBench.PartyShare? { position.flatMap(bench.party(at:)) }

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            Chart(bench.parties) { share in
                BarMark(
                    xStart: .value("Start", revealed ? share.start : 0),
                    xEnd: .value("Seats", revealed ? share.end : 0),
                    y: .value("Bench", bench.title),
                    height: .fixed(.regionBenchBar)
                )
                .foregroundStyle(PartyPalette.of(party: share.party).primary)
                .opacity(selected == nil || selected == share ? 1 : .opacitySoft)
                .accessibilityLabel(share.party)
                .accessibilityValue(
                    Text(verbatim: "\(PublicFormat.number(share.count)), \(bench.share(of: share))")
                )
                if share.end < bench.total {
                    RuleMark(x: .value("Edge", revealed ? share.end : 0))
                        .foregroundStyle(Color.plainRow)
                        .lineStyle(StrokeStyle(lineWidth: .spaceHairline))
                        .accessibilityHidden(true)
                }
            }
            .chartXScale(domain: 0...max(bench.total, 1), range: .plotDimension(endPadding: 0))
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
            .chartXSelection(value: $position)
            .chartPlotStyle { $0.clipShape(.capsule) }
            .frame(height: .regionBenchBar)
            .accessibilityLabel(Text("Composition by party"))
            if let selected {
                ChartCallout(title: selected.party, value: PublicFormat.number(selected.count)) {
                    Text(verbatim: bench.share(of: selected))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity)
            } else {
                Text("Touch the bar to see each party.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .sensoryFeedback(.selection, trigger: selected?.party)
        .onAppear {
            withAnimation(reduceMotion ? nil : .smooth(duration: 1)) { revealed = true }
        }
    }
}

private struct MineBenchLeaders: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let bench: MineBench

    var body: some View {
        let layout =
            dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: .spaceM))
            : AnyLayout(HStackLayout(alignment: .top, spacing: .spaceL))
        layout {
            ForEach(bench.leading) { share in
                VStack(alignment: .leading, spacing: .space2XS) {
                    Text(verbatim: PublicFormat.number(share.count))
                        .font(.amountRow)
                        .monospacedDigit()
                    PartyMark(share.party)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    Text(verbatim: "\(share.party), \(PublicFormat.number(share.count))"))
            }
            if bench.parties.count > MineBench.leadingLimit {
                VStack(alignment: .leading, spacing: .space2XS) {
                    Text(verbatim: "+\(bench.parties.count - MineBench.leadingLimit)")
                        .font(.amountRow)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Text("other parties")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

private struct MineFacePile: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let bench: MineBench

    var body: some View {
        HStack(spacing: .spaceM) {
            if !dynamicTypeSize.isAccessibilitySize {
                HStack(spacing: .regionFaceOverlap) {
                    ForEach(bench.faces) { card in
                        PersonPortrait(
                            slug: card.slug, name: card.name, party: card.party, size: .badgeM
                        )
                        .overlay {
                            Circle().strokeBorder(Color.plainRow, lineWidth: .spaceHairline)
                        }
                    }
                }
                .accessibilityHidden(true)
            }
            Spacer(minLength: 0)
            Text("See All (\(bench.total))")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .layoutPriority(1)
        }
        .padding(.vertical, .space2XS)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("See all \(bench.total) people of \(bench.title)"))
    }
}

private struct MineNextTermLink: View {
    let bench: MineBench

    var body: some View {
        if !bench.elected.isEmpty {
            NavigationLink {
                MineRosterScreen(
                    roster: MineRoster(
                        title: String(appLocalized: "Next Term"), people: bench.elected))
            } label: {
                HStack(spacing: .spaceM) {
                    Label("Next Term", systemImage: "calendar.badge.clock")
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: .spaceS)
                    Text("\(bench.elected.count) elected, awaiting inauguration")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
    }
}

struct MineSenateSection: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let bench: MineBench

    var body: some View {
        Section {
            if dynamicTypeSize.isAccessibilitySize {
                ForEach(bench.members) { MineRosterRow(card: $0) }
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: .regionMiniCard), spacing: .spaceM)],
                    spacing: .spaceM
                ) {
                    ForEach(bench.members) { MineSenatorCard(card: $0) }
                }
                .padding(.vertical, .spaceXS)
            }
            MineNextTermLink(bench: bench)
        } header: {
            Text(verbatim: bench.title).sectionTitle()
        } footer: {
            Text(verbatim: bench.subtitle)
        }
    }
}

private struct MineSenatorCard: View {
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section
    let card: PersonCard

    var body: some View {
        Button {
            open(.person(slug: card.slug), in: section)
        } label: {
            VStack(spacing: .spaceS) {
                PersonPortrait(slug: card.slug, name: card.name, party: card.party, size: .badgeXL)
                Text(verbatim: card.name)
                    .font(.footnote.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2, reservesSpace: true)
                PartyMark(card.party)
            }
            .padding(.spaceM)
            .frame(maxWidth: .infinity)
            .background(.subtleFill, in: .rect(cornerRadius: .radiusM))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(card.name), \(card.party), \(card.officeTitle)"))
        .accessibilityAddTraits(.isButton)
    }
}
