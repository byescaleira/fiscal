import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct RaceDetailScreen: View {
    @Environment(LiveResultsModel.self) private var results
    let raceID: String

    var body: some View {
        Group {
            if let race = results.race(id: raceID) {
                RaceDetailContent(race: race)
            } else {
                ContentUnavailableView(
                    "Race unavailable", systemImage: "chart.bar.xaxis",
                    description: Text("This race isn't in the latest TSE file."))
            }
        }
        .background(.groupedBackground)
        .fontDesign(.rounded)
        .navigationTitle(Text(verbatim: results.race(id: raceID).map(results.title) ?? ""))
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .refreshable { await results.refresh() }
    }
}

private struct RaceDetailContent: View {
    @Environment(LiveResultsModel.self) private var results
    let race: Race

    var body: some View {
        let summary = RaceSummary(race: race)
        ScrollView {
            VStack(alignment: .leading, spacing: .spaceXL) {
                RaceHeroCard(race: race, opensDetail: false)
                LazyVGrid(
                    columns: [
                        GridItem(
                            .adaptive(minimum: .cardColumn), spacing: .spaceXL, alignment: .top)
                    ],
                    alignment: .leading, spacing: .spaceXL
                ) {
                    RaceDetailSection(
                        title: String(appLocalized: "Candidates"), footer: summary.majorityText
                    ) {
                        RaceStandings(
                            contenders: summary.contenders, cut: summary.majorityCut,
                            showsVotes: true)
                    }
                    RaceDetailSection(
                        title: summary.ballotTitle,
                        footer: summary.ballots.isEmpty
                            ? nil
                            : String(
                                appLocalized:
                                    "Blank and null votes don't count toward the valid votes, which decide the race."
                            )
                    ) {
                        if summary.ballots.isEmpty {
                            Label {
                                Text(verbatim: summary.ballotLine)
                            } icon: {
                                Image(systemName: "clock")
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        } else {
                            RaceBallotChart(summary: summary)
                        }
                    }
                    RaceDetailSection(
                        title: String(appLocalized: "Count"), footer: summary.sourceText
                    ) {
                        RaceCountFacts(summary: summary)
                    }
                }
                if !race.final, let off = results.activitiesOffText {
                    Text(verbatim: off)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, .spaceXS)
                }
            }
            .padding(.horizontal, .spaceL)
            .padding(.bottom, .space2XL)
            .frame(maxWidth: .readableColumn * 2)
            .frame(maxWidth: .infinity)
        }
    }
}

struct RaceDetailSection<Content: View>: View {
    private let title: String
    private let footer: String?
    private let content: Content

    init(title: String, footer: String?, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceM) {
            Text(verbatim: title)
                .font(.titleMedium)
                .accessibilityAddTraits(.isHeader)
            content
                .padding(.spaceL)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.groupedRow, in: .rect(cornerRadius: .radiusGroup))
            if let footer {
                Text(verbatim: footer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, .spaceXS)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct RaceCountFacts: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let summary: RaceSummary

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceL) {
            VStack(alignment: .leading, spacing: .spaceS) {
                HStack(alignment: .firstTextBaseline) {
                    Text(verbatim: summary.countedText)
                        .font(.scoreboardNumber)
                        .monospacedDigit()
                        .contentTransition(
                            reduceMotion
                                ? .identity : .numericText(value: summary.race.sections.percent))
                    Spacer(minLength: .spaceS)
                    RaceStatusBadge(summary: summary)
                }
                ProgressBar(value: summary.countedFraction, color: .retroTeal)
                Text(verbatim: summary.sectionsText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .accessibilityElement(children: .combine)
            Divider()
            RaceFact(title: "Voters", value: summary.electorateText, symbol: "person.3")
            RaceFact(title: "Turnout", value: summary.turnoutText, symbol: "person.badge.clock")
        }
    }
}

private struct RaceFact: View {
    let title: LocalizedStringKey
    let value: String
    let symbol: String

    var body: some View {
        HStack {
            Label(title, systemImage: symbol)
                .foregroundStyle(.secondary)
            Spacer(minLength: .spaceS)
            Text(verbatim: value)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .font(.subheadline)
        .accessibilityElement(children: .combine)
    }
}
