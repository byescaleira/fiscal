import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct TodayRepresentativesSection: View {
    @Environment(TodayModel.self) private var today
    @Environment(FiscalNavigation.self) private var navigation: FiscalNavigation?

    var body: some View {
        let people = today.representatives
        TodaySection(
            "Your Representatives",
            source: people.isEmpty ? nil : today.recentSource,
            action: people.isEmpty ? nil : ("See All", { navigation?.selectedSection = .mine })
        ) {
            if people.isEmpty {
                FollowInvite { navigation?.selectedSection = .mine }
            } else {
                VStack(spacing: 0) {
                    ForEach(people) { person in
                        RepresentativeRow(person: person)
                        if person.id != people.last?.id {
                            Divider().padding(.leading, .badgeL + .spaceL + .spaceM)
                        }
                    }
                    if today.moreFollowed > 0 {
                        Divider().padding(.leading, .spaceL)
                        Button(TodayText.moreFollowed(today.moreFollowed)) {
                            navigation?.selectedSection = .mine
                        }
                        .font(.footnote.weight(.semibold))
                        .buttonStyle(.borderless)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.spaceL)
                    }
                }
                .todayCard()
            }
        }
    }
}

private struct RepresentativeRow: View {
    @Environment(TodayModel.self) private var today
    let person: TodayModel.Representative

    var body: some View {
        let card = person.card
        RouteButton(route: .person(slug: card.slug)) {
            AdaptiveRow(spacing: .spaceM) {
                HStack(spacing: .spaceM) {
                    PersonPortrait(slug: card.slug, name: card.name, party: card.party)
                    VStack(alignment: .leading, spacing: .space2XS) {
                        Text(verbatim: card.name)
                            .font(.rowTitle)
                            .lineLimit(2)
                        HStack(spacing: .spaceXS) {
                            PartyMark(card.party)
                            Text(verbatim: today.detail(for: card))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                Spacer(minLength: 0)
                if let ballot = person.ballot, let vote = person.vote {
                    VStack(alignment: .trailing, spacing: .space2XS) {
                        BallotChip(ballot: ballot)
                        Text(verbatim: vote.proposition)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, .spaceL)
            .padding(.vertical, .spaceM)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct FollowInvite: View {
    let openMine: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceM) {
            HStack(alignment: .top, spacing: .spaceM) {
                SymbolBadge("person.2", color: .info, size: .badgeL)
                VStack(alignment: .leading, spacing: .space2XS) {
                    Text("Follow who represents you").font(.headline)
                    Text(
                        "Pick your state in Mine to see your deputies, senators and governor here, with how they voted."
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)
            Button("Open Mine", systemImage: "person.2", action: openMine)
                .buttonStyle(.bordered)
                .font(.subheadline.weight(.semibold))
        }
        .padding(.spaceL)
        .todayCard()
    }
}
