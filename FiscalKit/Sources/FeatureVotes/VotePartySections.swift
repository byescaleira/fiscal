import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct VoteGuidanceSection: View {
    @Environment(VoteDetailModel.self) private var vote

    var body: some View {
        Section {
            if vote.guidanceGroups.isEmpty {
                Label("No party guidance was published for this vote.", systemImage: "minus")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(vote.guidanceGroups) { group in
                    VStack(alignment: .leading, spacing: .spaceS) {
                        BallotChip(group.guidance, choice: group.choice)
                        FlowLayout(spacing: .spaceXS) {
                            ForEach(group.parties, id: \.self) { PartyMark($0) }
                        }
                    }
                    .padding(.vertical, .space2XS)
                    .accessibilityElement(children: .combine)
                }
            }
        } header: {
            Text("Party Guidance").sectionTitle()
        } footer: {
            Text("What each party's leader asked the bench to vote. Parties in alphabetical order.")
        }
    }
}

struct VotePartySection: View {
    @Environment(VoteDetailModel.self) private var vote

    var body: some View {
        if !vote.partyRows.isEmpty {
            Section {
                ForEach(Array(vote.partyRows.enumerated()), id: \.element.id) { index, row in
                    PartyTallyRow(row: row, index: index)
                }
            } header: {
                Text("By Party").sectionTitle()
            } footer: {
                VStack(alignment: .leading, spacing: .space2XS) {
                    PartyLegend()
                    Text(
                        "Ordered by the size of each bench in this vote. Tap a party to see its names."
                    )
                    Text(verbatim: vote.sourceText)
                }
            }
        }
    }
}

private struct PartyTallyRow: View {
    @Environment(VoteDetailModel.self) private var vote
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appTint) private var tint
    @State private var fill = 0.0
    let row: VoteDetailModel.PartyRow
    let index: Int

    var body: some View {
        let isSelected = vote.party == row.party
        Button {
            vote.select(party: row.party)
        } label: {
            VStack(alignment: .leading, spacing: .spaceS) {
                AdaptiveRow(spacing: .spaceS) {
                    PartyMark(row.party)
                    Spacer(minLength: .spaceS)
                    PartyCounts(row: row)
                    if isSelected {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(tint)
                            .accessibilityHidden(true)
                    }
                }
                TallyBar(segments: segments, height: .barHeight, fill: fill * widthShare)
            }
            .padding(.vertical, .space2XS)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: vote.partyAccessibility(row)))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(Text("Shows only this party in the roll call"))
        .onAppear {
            guard fill == 0 else { return }
            if reduceMotion {
                fill = 1
            } else {
                withAnimation(.smooth(duration: 1).delay(Double(index) * 0.04)) { fill = 1 }
            }
        }
    }

    private var widthShare: Double {
        vote.largestBench > 0 ? Double(row.total) / Double(vote.largestBench) : 0
    }

    private var segments: [TallyBar.Segment] {
        BallotChoice.allCases.map { choice in
            TallyBar.Segment(
                id: choice.id, value: Double(row.count(choice)), color: choice.color,
                dashed: choice == .absent)
        }
    }
}

private struct PartyCounts: View {
    let row: VoteDetailModel.PartyRow

    var body: some View {
        HStack(spacing: .spaceS) {
            ForEach(BallotChoice.allCases) { choice in
                HStack(spacing: .spaceHairline) {
                    Image(systemName: choice.symbol)
                        .foregroundStyle(choice.color)
                    Text(verbatim: "\(row.count(choice))")
                        .monospacedDigit()
                }
            }
        }
        .font(.caption.weight(.semibold))
    }
}

private struct PartyLegend: View {
    var body: some View {
        FlowLayout(spacing: .spaceS) {
            ForEach(BallotChoice.allCases) { choice in
                Label(choice.groupTitle, systemImage: choice.symbol)
                    .foregroundStyle(choice.color)
            }
        }
        .font(.caption.weight(.semibold))
    }
}
