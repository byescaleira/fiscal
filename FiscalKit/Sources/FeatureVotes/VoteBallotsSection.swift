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
            BallotFilterPills()
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
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
            BallotMark(text: ballot.vote, choice: BallotChoice(vote: ballot.vote))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: vote.ballotAccessibility(ballot)))
    }
}

private struct BallotMark: View {
    @ScaledMetric(relativeTo: .caption) private var diameter: CGFloat = .badgeS
    let text: String
    let choice: BallotChoice?

    var body: some View {
        let color = choice?.color ?? .secondary
        HStack(spacing: .spaceS) {
            Text(verbatim: text)
                .font(.chipLabel)
                .foregroundStyle(color)
                .lineLimit(1)
            Image(systemName: choice?.symbol ?? "circle.dotted")
                .font(.chipLabel)
                .foregroundStyle(color)
                .frame(width: diameter, height: diameter)
                .background(color.opacity(.opacityTint), in: .circle)
        }
        .fixedSize()
    }
}

private struct BallotFilterPills: View {
    @Environment(VoteDetailModel.self) private var vote

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: .spaceS) {
                ForEach(VoteDetailModel.BallotFilter.allCases) { filter in
                    BallotFilterPill(
                        filter: filter, count: vote.count(filter),
                        isSelected: vote.ballotFilter == filter
                    ) {
                        vote.ballotFilter = filter
                    }
                }
            }
            .padding(.vertical, .spaceXS)
        }
        .scrollIndicators(.hidden)
        .sensoryFeedback(.selection, trigger: vote.ballotFilter)
    }
}

private struct BallotFilterPill: View {
    let filter: VoteDetailModel.BallotFilter
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        let color = filter.choice?.color ?? Color.primary
        Button(action: action) {
            HStack(spacing: .spaceXS) {
                if let symbol = filter.choice?.symbol {
                    Image(systemName: symbol).font(.caption.weight(.bold))
                }
                Text(verbatim: filter.title).font(.subheadline.weight(.semibold))
                Text(verbatim: PublicFormat.number(count))
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .opacity(isSelected ? 1 : .opacitySoft * 2)
            }
            .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(color))
            .padding(.horizontal, .spaceM)
            .padding(.vertical, .spaceS)
            .background {
                Capsule().fill(isSelected ? color : color.opacity(.opacityTint))
            }
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: "\(filter.title), \(PublicFormat.number(count))"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
