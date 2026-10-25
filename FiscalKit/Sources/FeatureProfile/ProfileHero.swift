import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct ProfileHeroSection: View {
    @Environment(ProfileModel.self) private var profile

    var body: some View {
        Section {
        } header: {
            if let person = profile.profile {
                ProfileHero(person: person)
                    .listRowInsets(EdgeInsets())
                    .textCase(nil)
            }
        }
    }
}

private struct ProfileHero: View {
    @Environment(ProfileModel.self) private var profile
    let person: Profile

    var body: some View {
        VStack(spacing: .spaceL) {
            HStack(spacing: .spaceS) {
                PartyMark(person.party)
                Spacer(minLength: .spaceS)
                if let status = profile.statusText {
                    Chip(status, color: profile.isInOffice ? .primary : .warning, shape: .capsule)
                }
            }
            PersonPortrait(
                slug: person.slug, name: person.name, party: person.party, size: .medallion
            )
            .overlay(Circle().strokeBorder(.white, lineWidth: .space2XS))
            VStack(spacing: .spaceXS) {
                Text(verbatim: person.name)
                    .font(.amountHero)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(verbatim: profile.officeLine)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                if let mandate = profile.mandateText {
                    Text(verbatim: mandate)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .multilineTextAlignment(.center)
            .accessibilityElement(children: .combine)
            ProfileHeroActions()
            if let vote = profile.lastVote {
                ProfileLastVote(vote: vote)
            }
        }
        .foregroundStyle(.primary)
        .padding(.spaceXL)
        .frame(maxWidth: .infinity)
        .background {
            PartyBackdrop(party: person.party).clipShape(.rect(cornerRadius: .radiusGroup))
        }
        .environment(\.colorScheme, .dark)
        .padding(.bottom, .spaceS)
    }
}

private struct ProfileHeroActions: View {
    @Environment(ProfileModel.self) private var profile
    @Environment(SessionModel.self) private var session
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section

    var body: some View {
        AdaptiveRow(spacing: .spaceM) {
            if profile.canFollow {
                Button {
                    Task {
                        await profile.toggleFollow()
                        session.reload()
                    }
                } label: {
                    Label(
                        profile.isFollowing ? LocalizedStringKey("Following") : "Follow",
                        systemImage: profile.isFollowing ? "checkmark" : "plus"
                    )
                    .frame(maxWidth: .infinity)
                }
                .heroGlassButton()
                .sensoryFeedback(.selection, trigger: profile.isFollowing)
            }
            if let route = profile.shareRoute {
                Button {
                    open(route, in: section)
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .heroGlassButton()
            }
        }
    }
}

private struct ProfileLastVote: View {
    @Environment(ProfileModel.self) private var profile
    let vote: PersonVote

    var body: some View {
        HStack(alignment: .center, spacing: .spaceM) {
            Capsule()
                .fill(.white)
                .frame(width: .space2XS)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: .space2XS) {
                if let text = profile.lastVoteText {
                    Text(verbatim: text).font(.caption.weight(.semibold)).foregroundStyle(
                        .secondary)
                }
                Text(verbatim: vote.summary)
                    .font(.footnote)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            BallotChip(ballot: profile.ballot(vote))
        }
        .padding(.spaceM)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.white.opacity(.opacityFill), in: .rect(cornerRadius: .radiusM))
        .accessibilityElement(children: .combine)
    }
}

struct BallotChip: View {
    let ballot: ProfileBallot

    var body: some View {
        Label(ballot.title, systemImage: ballot.symbol)
            .font(.chipLabel)
            .foregroundStyle(ballot.color)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, .spaceS)
            .padding(.vertical, .space2XS)
            .background(ballot.color.opacity(.opacityTint), in: .capsule)
            .overlay {
                if ballot == .absent {
                    Capsule().strokeBorder(
                        ballot.color,
                        style: StrokeStyle(
                            lineWidth: .spaceHairline / 2, dash: [.space2XS, .spaceHairline]))
                }
            }
    }
}

extension ProfileBallot {
    var color: Color {
        switch self {
        case .yes: .positive
        case .no: .negative
        case .abstention: .warning
        case .absent, .other: .secondary
        }
    }
}

extension View {
    @ViewBuilder fileprivate func heroGlassButton() -> some View {
        #if os(visionOS)
            buttonStyle(.bordered).controlSize(.large).font(.buttonLabel)
        #else
            buttonStyle(.glass).controlSize(.large).font(.buttonLabel)
        #endif
    }
}
