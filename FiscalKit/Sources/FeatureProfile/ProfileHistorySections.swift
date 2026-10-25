import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct ProfileAssetsSection: View {
    @Environment(ProfileModel.self) private var profile

    var body: some View {
        if !profile.assetDeclarations.isEmpty {
            Section {
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
                }
            } header: {
                Text("Declared Assets").sectionTitle()
            } footer: {
                ProfileFooter(
                    lines: [
                        profile.assetsNote, profile.sourceText(for: ["assets"]),
                    ])
            }
        }
    }
}

struct ProfileCampaignsSection: View {
    @Environment(ProfileModel.self) private var profile

    var body: some View {
        if !profile.campaigns.isEmpty {
            Section {
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
                    .padding(.vertical, .space2XS)
                    .accessibilityElement(children: .combine)
                }
            } header: {
                Text("Campaigns").sectionTitle()
            } footer: {
                ProfileFooter(lines: [profile.sourceText(for: ["campaigns"])])
            }
        }
    }
}

struct ProfileTimelineSection: View {
    @Environment(ProfileModel.self) private var profile

    var body: some View {
        if !profile.timeline.isEmpty {
            Section {
                ForEach(Array(profile.timeline.enumerated()), id: \.offset) { _, career in
                    HStack(alignment: .top, spacing: .spaceM) {
                        Text(verbatim: String(career.year))
                            .font(.titleMedium)
                            .fontWidth(.condensed)
                            .monospacedDigit()
                            .frame(width: .badgeXL, alignment: .leading)
                        VStack(alignment: .leading, spacing: .space2XS) {
                            Text(verbatim: career.office).font(.rowTitle)
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
                    .padding(.vertical, .space2XS)
                    .accessibilityElement(children: .combine)
                }
            } header: {
                Text("Career").sectionTitle()
            } footer: {
                ProfileFooter(lines: [profile.sourceText(for: ["timeline"])])
            }
        }
    }
}

struct ProfileCommitteesSection: View {
    @Environment(ProfileModel.self) private var profile

    var body: some View {
        if !profile.committees.isEmpty {
            Section {
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
            } header: {
                Text("Committees").sectionTitle()
            } footer: {
                ProfileFooter(lines: [profile.sourceText(for: ["votes"])])
            }
        }
    }
}

struct ProfileFactChecksSection: View {
    @Environment(ProfileModel.self) private var profile

    var body: some View {
        if profile.showsFactChecks {
            Section {
                IconRow(
                    "Fact checks", detail: "Checks published by fact-checking agencies.",
                    symbol: "checkmark.bubble", color: .retroDenim)
            } header: {
                Text("Fact Checks").sectionTitle()
            }
        }
    }
}

struct ProfileCoverageSection: View {
    @Environment(ProfileModel.self) private var profile

    var body: some View {
        if !profile.coverageLines.isEmpty {
            Section {
                ForEach(profile.coverageLines) { line in
                    HStack(spacing: .spaceM) {
                        Image(systemName: line.status.symbol)
                            .foregroundStyle(line.status == .available ? .primary : .secondary)
                            .frame(width: .badgeS)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: .spaceHairline) {
                            Text(verbatim: line.title).font(.rowTitle)
                            Text(verbatim: line.detail).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            } header: {
                Text("What the Sources Publish").sectionTitle()
            } footer: {
                Text(
                    "Some state assemblies don't publish attendance, votes or expenses as open data."
                )
            }
        }
    }
}

struct ProfileAboutSection: View {
    @Environment(ProfileModel.self) private var profile

    var body: some View {
        if !profile.aboutLines.isEmpty {
            Section {
                ForEach(profile.aboutLines) { line in
                    LabeledContent {
                        Text(verbatim: line.value).multilineTextAlignment(.trailing)
                            .textSelection(.enabled)
                    } label: {
                        Text(verbatim: line.title)
                    }
                }
            } header: {
                Text("About").sectionTitle()
            } footer: {
                ProfileFooter(lines: [profile.sourceText])
            }
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
                .fontWidth(.condensed)
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

extension Profile.Coverage.Status {
    var symbol: String {
        switch self {
        case .available: "checkmark.circle"
        case .notPublished: "minus.circle"
        case .notLoaded: "clock"
        }
    }
}
