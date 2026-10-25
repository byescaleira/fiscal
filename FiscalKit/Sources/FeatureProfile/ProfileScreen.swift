import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public struct ProfileScreen: View {
    @Environment(ProfileModel.self) private var profile

    public init() {}

    public var body: some View {
        @Bindable var profile = profile
        PublicDataContent(
            phase: profile.phase, isEmpty: profile.isEmpty, retry: { await profile.load() }
        ) {
            AdaptiveList {
                ProfileHeroSection()
                ProfileNumbersSection()
                ProfileLensSection()
                ProfileVotesSection()
                ProfileProposalsSection()
                ProfileSpeechesSection()
                ProfileExpensesSection()
                ProfileAssetsSection()
                ProfileCampaignsSection()
                ProfileTimelineSection()
                ProfileCommitteesSection()
                ProfileFactChecksSection()
                ProfileCoverageSection()
                ProfileAboutSection()
            }
        } empty: {
            ProfileEmptyState()
        }
        .fontDesign(.rounded)
        .navigationTitle(profile.title)
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .refreshable { await profile.load() }
        .task { await profile.load() }
        .errorAlert($profile.error)
    }
}

struct ProfileNumbersSection: View {
    @Environment(ProfileModel.self) private var profile
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Section {
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: .spaceS, alignment: .top),
                    count: dynamicTypeSize.isAccessibilitySize ? 1 : 2),
                spacing: .spaceS
            ) {
                ForEach(profile.facts) { NumberTileView(tile: $0) }
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            ProfileNumbersExplainer()
        } header: {
            Text("Term in Numbers").sectionTitle()
        } footer: {
            Text(verbatim: profile.numbersFootnote)
        }
    }
}

private struct NumberTileView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var filled = false
    let tile: ProfileModel.NumberTile

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceXS) {
            Label(tile.title, systemImage: tile.symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(verbatim: tile.value)
                .font(.amountTitle)
                .monospacedDigit()
                .foregroundStyle(tile.isMissing ? .tertiary : .primary)
                .amountLine()
            if let fraction = tile.fraction {
                ProgressBar(value: filled ? fraction : 0, color: .retroTeal)
                    .animation(reduceMotion ? nil : .smooth(duration: 1), value: filled)
                    .onAppear { filled = true }
            }
            if let caption = tile.caption {
                Text(verbatim: caption).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if let source = tile.source {
                Text(verbatim: source).font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(.spaceM)
        .frame(maxWidth: .infinity, minHeight: .ring + .spaceXL, alignment: .topLeading)
        .background(.groupedRow, in: .rect(cornerRadius: .radiusM))
        .accessibilityElement(children: .combine)
    }
}

struct ProfileLensSection: View {
    @Environment(ProfileModel.self) private var profile
    @Environment(\.appTint) private var tint

    var body: some View {
        if !profile.themeLines.isEmpty {
            Section {
                if let headline = profile.lensVotesHeadline {
                    VStack(alignment: .leading, spacing: .spaceS) {
                        Text(verbatim: headline).font(.headline)
                        FlowLayout(spacing: .spaceXS) {
                            ForEach(profile.lensBallots) { item in
                                BallotCountChip(item: item)
                            }
                        }
                    }
                    .padding(.vertical, .space2XS)
                    .accessibilityElement(children: .combine)
                }
                ForEach(profile.themeLines) { line in
                    HStack(spacing: .spaceM) {
                        Image(systemName: line.theme.symbol)
                            .font(.icon(.s, weight: .medium))
                            .foregroundStyle(line.isLensTheme ? tint : .secondary)
                            .frame(width: .badgeM, height: .badgeM)
                            .background(
                                (line.isLensTheme ? tint : .secondary).opacity(.opacityTint),
                                in: .rect(cornerRadius: .radiusS)
                            )
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: .spaceHairline) {
                            Text(verbatim: line.theme.title).font(.rowTitle)
                            Text(verbatim: profile.themeDetail(line))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: .spaceS)
                        if line.isLensTheme {
                            Image(systemName: "eyeglasses")
                                .foregroundStyle(tint)
                                .accessibilityLabel(Text("By your lens"))
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            } header: {
                AdaptiveStack(spacing: .spaceS) {
                    Text(profile.lensThemes.isEmpty ? LocalizedStringKey("Themes") : "By Your Lens")
                        .sectionTitle()
                    Spacer(minLength: 0)
                    if let stance = profile.lensStance { LensBadge(stance) }
                }
                .textCase(nil)
            } footer: {
                Text(verbatim: profile.lensFootnote)
            }
        }
    }
}

private struct BallotCountChip: View {
    let item: ProfileModel.BallotCount

    var body: some View {
        HStack(spacing: .space2XS) {
            BallotChip(ballot: item.ballot)
            Text(verbatim: PublicFormat.number(item.count))
                .font(.headline)
                .monospacedDigit()
        }
    }
}

private struct ProfileEmptyState: View {
    var body: some View {
        EmptyStateView(
            title: "Profile not loaded",
            description:
                "Attendance, votes, proposals, expenses and assets show up here, each with its official source."
        ) {
            IconRow("Votes", symbol: "checkmark.square", color: .retroDenim)
            IconRow("Expenses", symbol: "brazilianrealsign", color: .retroOlive)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.groupedBackground)
    }
}
