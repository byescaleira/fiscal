import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct ProfileAssetsSection: View {
    @Environment(ProfileModel.self) private var profile

    var body: some View {
        if !profile.assetDeclarations.isEmpty {
            ProfileBlock(
                title: Text("Declared Assets"),
                footer: [profile.assetsNote, profile.sourceText(for: ["assets"])]
            ) {
                ForEach(profile.assetDeclarations) { declaration in
                    DisclosureGroup {
                        ForEach(Array(declaration.items.enumerated()), id: \.offset) { _, item in
                            LabeledContent {
                                Text(verbatim: profile.money(item.cents)).monospacedDigit()
                            } label: {
                                Text(verbatim: item.kind)
                            }
                            .font(.subheadline)
                        }
                    } label: {
                        ProfileYearLine(
                            year: declaration.year, title: nil,
                            value: profile.money(declaration.totalCents))
                    }
                    .tint(Color.primary)
                }
            }
        }
    }
}

struct ProfileCampaignsSection: View {
    @Environment(ProfileModel.self) private var profile

    var body: some View {
        if !profile.campaigns.isEmpty {
            ProfileBlock(
                title: Text("Campaigns"), footer: [profile.sourceText(for: ["campaigns"])]
            ) {
                ForEach(Array(profile.campaigns.enumerated()), id: \.offset) { _, campaign in
                    VStack(alignment: .leading, spacing: .spaceXS) {
                        ProfileYearLine(
                            year: campaign.year, title: profile.campaignDetail(campaign),
                            value: nil)
                        LabeledContent("Raised") {
                            Text(verbatim: profile.money(campaign.revenueCents)).monospacedDigit()
                        }
                        LabeledContent("Spent") {
                            Text(verbatim: profile.money(campaign.expenseCents)).monospacedDigit()
                        }
                    }
                    .font(.subheadline)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

struct ProfileTimelineSection: View {
    @Environment(ProfileModel.self) private var profile

    var body: some View {
        if !profile.timeline.isEmpty {
            ProfileBlock(title: Text("Career"), footer: [profile.sourceText(for: ["timeline"])]) {
                ForEach(Array(profile.timeline.enumerated()), id: \.offset) { _, career in
                    HStack(alignment: .top, spacing: .spaceM) {
                        Text(verbatim: String(career.year))
                            .font(.titleMedium)
                            .monospacedDigit()
                            .frame(width: .badgeXL, alignment: .leading)
                        VStack(alignment: .leading, spacing: .space2XS) {
                            Text(verbatim: profile.careerOffice(career)).font(.rowTitle)
                            Text(verbatim: profile.careerDetail(career))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            if let votes = profile.careerVotes(career) {
                                Text(verbatim: votes)
                                    .font(.footnote)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

struct ProfileCommitteesSection: View {
    @Environment(ProfileModel.self) private var profile

    var body: some View {
        if !profile.committees.isEmpty {
            ProfileBlock(title: Text("Committees"), footer: [profile.sourceText(for: ["votes"])]) {
                ForEach(Array(profile.committees.enumerated()), id: \.offset) { _, committee in
                    VStack(alignment: .leading, spacing: .space2XS) {
                        Text(verbatim: committee.name).font(.rowTitle)
                        let detail = profile.committeeDetail(committee)
                        if !detail.isEmpty {
                            Text(verbatim: detail).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

struct ProfileAboutSection: View {
    @Environment(ProfileModel.self) private var profile

    var body: some View {
        if !profile.aboutLines.isEmpty {
            ProfileBlock(footer: [profile.sourceText]) {
                ForEach(profile.aboutLines) { line in
                    LabeledContent {
                        Text(verbatim: line.value).multilineTextAlignment(.trailing)
                            .textSelection(.enabled)
                    } label: {
                        Text(verbatim: line.title)
                    }
                }
            }
        }
        if !profile.gaps.isEmpty {
            ProfileFooter(lines: profile.gaps)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, .spaceL)
        }
    }
}

private struct ProfileYearLine: View {
    let year: Int
    let title: String?
    let value: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: .spaceM) {
            Text(verbatim: String(year))
                .font(.amountRow)
                .monospacedDigit()
            if let title {
                Text(verbatim: title).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: .spaceS)
            if let value {
                Text(verbatim: value).font(.body.weight(.semibold)).monospacedDigit()
            }
        }
    }
}
