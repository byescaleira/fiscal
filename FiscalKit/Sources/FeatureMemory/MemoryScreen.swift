import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public struct MemoryScreen: View {
    @Environment(MemoryModel.self) private var memory

    public init() {}

    public var body: some View {
        AdaptiveList {
            MemoryHeroSection()
            ElectionScheduleSection()
            if !memory.presidential.isEmpty {
                PresidentialTimelineSection()
            }
            if !memory.otherYears.isEmpty {
                OtherYearsSection()
            }
            if !memory.periods.isEmpty {
                PeriodsSection()
            }
            if !memory.guides.isEmpty {
                StudySection()
            }
            if let error = memory.phase.error {
                MemoryIssueSection(error: error)
            }
        }
        .emphasisTitle("Memory")
        .refreshable { await memory.load() }
        .task { await memory.load() }
    }
}

private struct MemoryHeroSection: View {
    @Environment(MemoryModel.self) private var memory
    @Environment(\.appTint) private var tint
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Section {
        } header: {
            VStack(spacing: .spaceS) {
                Chip("SINCE THE PROCLAMATION OF THE REPUBLIC", color: tint, shape: .capsule)
                Text("\(memory.republicYears) years")
                    .font(.amountHero)
                    .monospacedDigit()
                    .contentTransition(
                        reduceMotion ? .identity : .numericText(value: Double(memory.republicYears)))
                    .foregroundStyle(.primary)
                Text(
                    "Past elections, the phases of Brazilian politics and guides to study, with a source on every fact."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .textCase(nil)
            .padding(.vertical, .spaceL)
        }
    }
}

private struct PresidentialTimelineSection: View {
    @Environment(MemoryModel.self) private var memory
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section

    var body: some View {
        Section {
            EdgeToEdgeRail(lazy: true) {
                ForEach(memory.presidential) { race in
                    if let winner = memory.winner(of: race) {
                        Button {
                            open(.pastElection(year: race.year), in: section)
                        } label: {
                            PastWinnerCard(
                                year: race.year, caption: memory.roundLine(race),
                                winner: winner, runnerUp: memory.runnerUp(of: race),
                                footnote: memory.turnoutLine(race)
                            )
                            .containerRelativeFrame(.horizontal) { width, _ in
                                .railCard(
                                    in: width, share: .winnerCardShare,
                                    columnShare: .winnerCardColumnShare)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(verbatim: memory.accessibility(race)))
                        .accessibilityHint(
                            Text("Shows every candidate, the map and the turnout"))
                    }
                }
            }
        } header: {
            Text("Presidential elections").sectionTitle().railHeader()
        } footer: {
            Text(verbatim: memory.electionFooter).railHeader()
        }
        .railSection()
    }
}

private struct OtherYearsSection: View {
    @Environment(MemoryModel.self) private var memory

    var body: some View {
        Section {
            ForEach(memory.otherYears, id: \.self) { year in
                RouteLink(.pastElection(year: year)) {
                    HStack(spacing: .spaceM) {
                        Text(verbatim: String(year))
                            .font(.scoreboardTitle)
                            .monospacedDigit()
                        VStack(alignment: .leading, spacing: .spaceHairline) {
                            Text("Governors and Senate").font(.rowTitle)
                            Text("No presidential election this year")
                                .font(.rowDetail)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        } header: {
            Text("State elections").sectionTitle()
        }
    }
}

private struct PeriodsSection: View {
    @Environment(MemoryModel.self) private var memory

    var body: some View {
        Section {
            ForEach(memory.periods) { period in
                RouteLink(.period(id: period.id)) {
                    PeriodRow(period: period, isLast: period.id == memory.periods.last?.id)
                }
            }
        } header: {
            Text("Brazilian politics, phase by phase").sectionTitle()
        } footer: {
            Text(verbatim: memory.periodsFooter)
        }
    }
}

private struct PeriodRow: View {
    let period: PoliticalPeriod
    let isLast: Bool

    var body: some View {
        TimelineRow(isLast: isLast) {
            Circle()
                .fill(PeriodPalette.color(for: period.era))
                .frame(width: .spaceM, height: .spaceM)
                .accessibilityHidden(true)
        } content: {
            VStack(alignment: .leading, spacing: .space2XS) {
                Text(verbatim: period.eraTitle)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(PeriodPalette.color(for: period.era))
                Text(verbatim: period.name).font(.rowTitle)
                Text(verbatim: period.yearsText)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Text(verbatim: period.summary)
                    .font(.rowDetail)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            .padding(.bottom, .spaceXS)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct StudySection: View {
    @Environment(MemoryModel.self) private var memory
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Section {
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: .spaceM),
                    count: dynamicTypeSize.isAccessibilitySize ? 1 : 2),
                spacing: .spaceM
            ) {
                ForEach(Array(memory.guides.enumerated()), id: \.element.id) { index, guide in
                    Button {
                        open(.studyGuide(id: guide.id), in: section)
                    } label: {
                        StudyTile(guide: guide, color: ChartPalette.color(at: index))
                    }
                    .buttonStyle(.plain)
                }
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        } header: {
            Text("To study").sectionTitle()
        } footer: {
            Text(
                "Short guides with the official source on each card, and a quiz with no score by side."
            )
        }
    }
}

private struct StudyTile: View {
    let guide: StudyGuide
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            SymbolBadge(guide.symbol, color: color, size: .badgeM)
            Spacer(minLength: .spaceS)
            Text(verbatim: guide.title)
                .font(.headline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: guide.countText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: .medallion, alignment: .topLeading)
        .padding(.spaceL)
        .background(.plainRow, in: .rect(cornerRadius: .radiusL))
        .contentShape(.rect(cornerRadius: .radiusL))
        .accessibilityElement(children: .combine)
    }
}

private struct MemoryIssueSection: View {
    @Environment(MemoryModel.self) private var memory
    let error: PublicDataError

    var body: some View {
        Section {
            IconRow(verbatim: error.message, symbol: error.symbol, color: .retroRust)
            Button("Try Again") { Task { await memory.load() } }
                .font(.buttonLabel)
        } footer: {
            Text("The election calendar above still works.")
        }
    }
}
