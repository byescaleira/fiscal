import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct VoteRepresentativesSection: View {
    @Environment(VoteDetailModel.self) private var vote

    var body: some View {
        if let people = vote.representatives {
            Section {
                if people.isEmpty {
                    Label(
                        "None of your state's representatives is on this roll call.",
                        systemImage: "person.2"
                    )
                    .foregroundStyle(.secondary)
                } else {
                    ForEach(people) { BallotRow(ballot: $0, size: .badgeL) }
                }
            } header: {
                Text(verbatim: vote.representativesTitle).sectionTitle()
            } footer: {
                Text("The state you chose in Mine. Names in alphabetical order.")
            }
        }
    }
}

struct VoteBallotsSection: View {
    @Environment(VoteDetailModel.self) private var vote

    var body: some View {
        @Bindable var vote = vote
        Section {
            Picker("Vote", selection: $vote.ballotFilter) {
                ForEach(VoteDetailModel.BallotFilter.allCases) { filter in
                    Text(verbatim: filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            if let party = vote.party {
                Button {
                    vote.select(party: nil)
                } label: {
                    HStack(spacing: .spaceS) {
                        Text("Showing only")
                        PartyMark(party)
                        Spacer(minLength: .spaceS)
                        Image(systemName: "xmark.circle")
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Remove the party filter \(party)"))
            }
            let ballots = vote.ballots
            if ballots.isEmpty {
                Text(verbatim: vote.ballotsEmptyText).foregroundStyle(.secondary)
            } else {
                ForEach(ballots) { BallotRow(ballot: $0, size: .badgeM) }
            }
        } header: {
            Text(verbatim: vote.ballotsTitle).sectionTitle()
        } footer: {
            VStack(alignment: .leading, spacing: .space2XS) {
                Text("Names in alphabetical order. Search by name, party or state.")
                Text(verbatim: vote.sourceText)
            }
        }
    }
}

private struct BallotRow: View {
    @Environment(VoteDetailModel.self) private var vote
    let ballot: VoteDetail.Ballot
    let size: CGFloat

    var body: some View {
        if let slug = ballot.slug {
            RouteLink(.person(slug: slug)) { content(slug: slug) }
        } else {
            content(slug: ballot.id)
        }
    }

    private func content(slug: String) -> some View {
        AdaptiveRow(spacing: .spaceM) {
            HStack(spacing: .spaceM) {
                PersonPortrait(slug: slug, name: ballot.name, party: ballot.party, size: size)
                VStack(alignment: .leading, spacing: .spaceHairline) {
                    Text(verbatim: ballot.name).font(.rowTitle)
                    Text(verbatim: vote.ballotDetail(ballot))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: .spaceS)
            BallotChip(ballot.vote, choice: BallotChoice(vote: ballot.vote))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: vote.ballotAccessibility(ballot)))
    }
}
