import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public struct RaceDetailScreen: View {
    @Environment(LiveResultsModel.self) private var results
    let raceID: String

    public init(raceID: String) {
        self.raceID = raceID
    }

    public var body: some View {
        Group {
            switch results.detailPhase(for: raceID) {
            case .ready(let summary):
                RaceDetailContent(summary: summary)
            case .loading:
                ProgressView("Loading").frame(maxWidth: .infinity, maxHeight: .infinity)
            case .unavailable:
                RaceDetailUnavailable(raceID: raceID)
            }
        }
        .background(.plainBackground)
        .navigationTitle(Text(verbatim: results.detailTitle(for: raceID)))
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(removing: .title)
        #endif
        .task { await results.loadDetail(id: raceID) }
    }
}

private struct RaceDetailUnavailable: View {
    @Environment(LiveResultsModel.self) private var results
    let raceID: String

    var body: some View {
        EmptyStateView(
            title: "Race unavailable", description: "This race isn't in the latest TSE file.",
            actionTitle: "Try Again", action: { Task { await results.loadDetail(id: raceID) } }
        ) {
            IconRow(
                "Official count", detail: "TSE", symbol: "checkmark.seal", color: .retroTeal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct RaceDetailContent: View {
    @Environment(LiveResultsModel.self) private var results
    let summary: RaceSummary

    var body: some View {
        RevealPage(
            chapters: [String](),
            maxWidth: .readableColumn * 2,
            refresh: { await results.refresh() },
            content: { _ in
                RaceHeroCard(race: summary.race, opensDetail: false).revealHero()
                CardGrid(minimumWidth: .cardColumn, spacing: .spaceXL) {
                    RaceCandidatesSection(summary: summary)
                    RaceBallotsSection(summary: summary)
                    RaceCountSection(summary: summary)
                }
            },
            bar: { _, _ in
                RaceStickyHeader(summary: summary)
            })
    }
}

private struct RaceStickyHeader: View {
    @Environment(LiveResultsModel.self) private var results
    let summary: RaceSummary

    var body: some View {
        AdaptiveRow(spacing: .spaceM) {
            Text(verbatim: results.detailTitle(for: summary.race.id))
                .font(.headline)
                .lineLimit(1)
            Spacer(minLength: .spaceS)
            HStack(alignment: .firstTextBaseline, spacing: .space2XS) {
                Text(verbatim: summary.countedText)
                    .font(.amountRow)
                    .monospacedDigit()
                Text(summary.race.final ? "TSE" : "counted")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .fixedSize()
        }
        .padding(.horizontal, .spaceL)
        .padding(.vertical, .spaceS)
        .frame(maxWidth: .readableColumn * 2, alignment: .leading)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

private struct RaceCandidatesSection: View {
    let summary: RaceSummary

    var body: some View {
        RaceDetailSection(title: Text("Candidates"), footer: summary.majorityText) {
            RaceStandings(
                contenders: summary.contenders, cut: summary.majorityCut, showsVotes: true)
        }
    }
}

private struct RaceBallotsSection: View {
    let summary: RaceSummary

    var body: some View {
        RaceDetailSection(title: Text(verbatim: summary.ballotTitle), footer: summary.ballotFooter)
        {
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
    }
}

private struct RaceCountSection: View {
    let summary: RaceSummary

    var body: some View {
        RaceDetailSection(title: Text("Count"), footer: summary.sourceText) {
            RaceCountFacts(summary: summary)
        }
    }
}

private struct RaceDetailSection<Content: View>: View {
    private let title: Text
    private let footer: String?
    private let content: Content

    init(title: Text, footer: String?, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceM) {
            title
                .sectionTitle()
                .accessibilityAddTraits(.isHeader)
            content
                .padding(.spaceL)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.plainRow, in: .rect(cornerRadius: .radiusGroup))
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
    @ReducesMotion private var reduceMotion
    let summary: RaceSummary

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceL) {
            VStack(alignment: .leading, spacing: .spaceS) {
                HStack(alignment: .firstTextBaseline) {
                    Text(verbatim: summary.countedText)
                        .font(.scoreboardTitle)
                        .monospacedDigit()
                        .amountLine()
                        .contentTransition(
                            reduceMotion
                                ? .identity : .numericText(value: summary.race.sections.percent))
                    Spacer(minLength: .spaceS)
                    RaceStatusBadge(summary: summary)
                }
                RaceCountBar(value: summary.countedFraction, color: .retroTeal)
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
