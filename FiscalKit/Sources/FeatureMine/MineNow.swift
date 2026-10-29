import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct MineNowSection: View {
    @Environment(MineModel.self) private var mine

    var body: some View {
        if mine.isLoadingActivity {
            Section {
                ProgressView("Loading")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, .spaceL)
            } header: {
                Text("In Your Region Now").sectionTitle()
            }
        } else if !mine.activity.isEmpty {
            if !mine.activity.highlights.isEmpty {
                Section {
                    ForEach(mine.activity.highlights) { highlight in
                        MineHighlightCard(highlight: highlight)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                } header: {
                    Text("In Your Region Now").sectionTitle()
                }
            }
            if !mine.activity.votes.isEmpty {
                Section {
                    ForEach(mine.activity.votes) { MineVoteRow(vote: $0) }
                } header: {
                    if mine.activity.highlights.isEmpty {
                        Text("In Your Region Now").sectionTitle()
                    } else {
                        Text("Recent Votes").sectionTitle()
                    }
                } footer: {
                    VStack(alignment: .leading, spacing: .space2XS) {
                        Text(
                            "Counts only the representatives of this state. Who isn't in the roll call counts as absent."
                        )
                        if let source = mine.activitySource { Text(verbatim: source) }
                    }
                }
            }
        }
    }
}

private struct MineHighlightCard: View {
    @Environment(MineModel.self) private var mine
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section
    @ReducesMotion private var reduceMotion
    @State private var appeared = false
    let highlight: Highlight

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceL) {
            HStack(spacing: .spaceS) {
                Chip(
                    mine.highlightKicker(highlight).uppercased(with: .app), color: .white,
                    shape: .capsule
                )
                .environment(\.colorScheme, .dark)
                Spacer(minLength: .spaceS)
                Label(mine.highlightScope, systemImage: "mappin")
                    .font(.caption.weight(.semibold))
                    .opacity(.opacityStrong)
                    .lineLimit(1)
            }
            Button {
                if let route = mine.route(for: highlight) { open(route, in: section) }
            } label: {
                content.contentShape(.rect)
            }
            .buttonStyle(.plain)
            .disabled(mine.route(for: highlight) == nil)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: mine.highlightAccessibility(highlight)))
            .accessibilityAddTraits(.isButton)
            WeightMethodButton(method: mine.activity.method)
                .tint(.white)
        }
        .padding(.spaceInset)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.scoreboard, in: .rect(cornerRadius: .radiusGroup))
        .onAppear {
            withAnimation(reduceMotion ? nil : .chartReveal(0)) { appeared = true }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: .spaceM) {
            if let person = highlight.person {
                HStack(spacing: .spaceM) {
                    PersonPortrait(
                        slug: person.slug, name: person.name, party: person.party,
                        size: .badgeXL
                    )
                    .overlay { Circle().strokeBorder(.white, lineWidth: .spaceHairline) }
                    VStack(alignment: .leading, spacing: .space2XS) {
                        Text(verbatim: person.name)
                            .font(.emphasis(.headline, weight: .bold))
                            .lineLimit(2)
                        HStack(spacing: .spaceXS) {
                            PartyMark(person.party)
                            Text(verbatim: person.officeTitle)
                                .font(.caption.weight(.semibold))
                                .opacity(.opacityStrong)
                                .lineLimit(1)
                        }
                    }
                }
            }
            Text(verbatim: highlight.title)
                .font(.emphasis(.title3, weight: .bold))
                .lineLimit(5)
                .fixedSize(horizontal: false, vertical: true)
            if highlight.person == nil {
                Text(verbatim: highlight.subtitle)
                    .font(.subheadline.weight(.semibold))
                    .opacity(.opacityStrong)
            }
            VStack(alignment: .leading, spacing: .spaceXS) {
                HStack(alignment: .firstTextBaseline, spacing: .spaceS) {
                    Text(verbatim: Relevance(weight: highlight.weight).title)
                        .font(.emphasis(.subheadline, weight: .bold))
                    Spacer(minLength: .spaceS)
                    Text("weight \(highlight.weight) of 100")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .opacity(.opacityStrong)
                }
                ProgressBar(value: appeared ? highlight.weightShare : 0, color: .white)
                if let text = highlight.coverage.uncertaintyShort {
                    Label(text, systemImage: "info.circle")
                        .font(.caption.weight(.medium))
                        .opacity(.opacityStrong)
                }
            }
        }
    }
}

private struct MineVoteRow: View {
    @Environment(MineModel.self) private var mine
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section
    let vote: MineVote

    var body: some View {
        let board = vote.board
        Button {
            open(.vote(id: vote.id), in: section)
        } label: {
            VStack(alignment: .leading, spacing: .spaceS) {
                HStack(spacing: .spaceS) {
                    Text(verbatim: board.eyebrow)
                        .font(.chipLabel)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: .spaceS)
                    Label(board.outcomeTitle, systemImage: board.outcomeSymbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Text(verbatim: board.summary)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                SameDayVotesMark(vote: vote.vote)
                VStack(alignment: .leading, spacing: .spaceXS) {
                    Text(verbatim: vote.heading)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    TallyChart(
                        segments: BallotChoice.allCases.map { choice in
                            TallyChart.Segment(
                                id: choice.rawValue, title: choice.title,
                                value: Double(vote.count(choice)), color: choice.color,
                                dashed: choice == .absent)
                        }, height: .spaceS)
                    Text(verbatim: vote.countsText)
                        .font(.footnote.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, .spaceXS)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: mine.voteAccessibility(vote)))
        .accessibilityAddTraits(.isButton)
    }
}
