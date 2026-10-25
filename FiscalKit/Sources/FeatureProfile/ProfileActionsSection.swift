import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct ProfileActionsSection: View {
    @Environment(ProfileModel.self) private var profile

    var body: some View {
        if !profile.actionItems.isEmpty {
            Section {
                ForEach(profile.actionItems) { item in
                    ProfileActionLink(item: item)
                }
            } header: {
                AdaptiveStack(spacing: .spaceS) {
                    Text("What They're Doing").sectionTitle()
                    Spacer(minLength: 0)
                    WeightMethodButton(method: profile.weightMethod)
                }
                .textCase(nil)
            } footer: {
                ProfileFooter(
                    lines: [
                        profile.actionsRuleText, profile.actionsTotalText,
                        profile.actionsSourceText,
                    ])
            }
        }
    }
}

private struct ProfileActionLink: View {
    @Environment(ProfileModel.self) private var profile
    let item: ActionItem

    var body: some View {
        let label = Text(verbatim: profile.actionAccessibility(item))
        if let route = profile.actionRoute(item) {
            RouteLink(route) { ProfileActionRow(item: item) }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(label)
                .accessibilityAddTraits(.isButton)
        } else if let url = item.url {
            Link(destination: url) { ProfileActionRow(item: item) }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(label)
                .accessibilityAddTraits(.isLink)
        } else {
            ProfileActionRow(item: item)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(label)
        }
    }
}

private struct ProfileActionRow: View {
    @Environment(ProfileModel.self) private var profile
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var filled = false
    let item: ActionItem

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceXS) {
            HStack(alignment: .firstTextBaseline, spacing: .spaceS) {
                Text(verbatim: profile.actionKicker(item))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let ballot = profile.actionBallot(item) {
                    BallotChip(ballot: ballot)
                }
            }
            Text(verbatim: item.title)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(4)
            HStack(spacing: .spaceS) {
                ProgressBar(value: filled ? Double(item.weight) / 100 : 0, color: .retroTeal)
                    .animation(reduceMotion ? nil : .smooth(duration: 1), value: filled)
                    .onAppear { filled = true }
                Text(verbatim: "\(item.weight)")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            WeightChips(
                repercussion: item.repercussion, impact: item.impact,
                isTest: item.signals.isTest)
        }
        .padding(.vertical, .space2XS)
    }
}
