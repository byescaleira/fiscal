import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct ProfileChapterView: View {
    @Environment(ProfileModel.self) private var profile
    let chapter: ProfileChapter

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceL) {
            Text(verbatim: profile.title(of: chapter))
                .font(.titleMedium)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            ProfileFactGrid(chapter: chapter)
            content
        }
    }

    @ViewBuilder private var content: some View {
        switch chapter {
        case .votes:
            ProfileVotesSection()
            ProfileThemesSection()
        case .proposals:
            ProfileActionsSection()
            ProfileProposalsSection()
            ProfileSpeechesSection()
            ProfileCommitteesSection()
        case .money:
            ProfileMoneyChapter()
            ProfileSalarySection()
        case .origin:
            ProfileAssetsSection()
            ProfileCampaignsSection()
            ProfileTimelineSection()
        case .term:
            ProfileContextSection()
        case .checks:
            ProfileChecksChapter()
        case .about:
            ProfileAboutSection()
        }
    }
}

struct ProfileBlock<Content: View, Accessory: View>: View {
    private let title: Text?
    private let footer: [String?]
    private let accessory: Accessory
    private let content: Content

    init(
        title: Text? = nil, footer: [String?] = [], @ViewBuilder content: () -> Content,
        @ViewBuilder accessory: () -> Accessory = { EmptyView() }
    ) {
        self.title = title
        self.footer = footer
        self.content = content()
        self.accessory = accessory()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            if let title {
                AdaptiveStack(spacing: .spaceS) {
                    title
                        .sectionTitle()
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 0)
                    accessory
                }
            }
            VStack(alignment: .leading, spacing: 0) {
                Group(subviews: content) { rows in
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        if index > 0 { Divider() }
                        row.padding(.vertical, .spaceM)
                    }
                }
            }
            .padding(.horizontal, .spaceL)
            .padding(.vertical, .spaceXS)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.plainRow, in: .rect(cornerRadius: .radiusGroup))
            if footer.contains(where: { $0 != nil }) {
                ProfileFooter(lines: footer)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, .spaceL)
            }
        }
    }
}

struct ProfileFactGrid: View {
    @Environment(ProfileModel.self) private var profile
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let chapter: ProfileChapter

    private var rows: [[ProfileModel.NumberTile]] {
        let width = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        var rows: [[ProfileModel.NumberTile]] = []
        for tile in profile.facts(in: chapter) {
            if tile.peer == nil, let last = rows.last, last.count < width,
                last.allSatisfy({ $0.peer == nil })
            {
                rows[rows.count - 1].append(tile)
            } else {
                rows.append([tile])
            }
        }
        return rows
    }

    var body: some View {
        let tiles = profile.facts(in: chapter)
        if !tiles.isEmpty {
            VStack(alignment: .leading, spacing: .spaceS) {
                ForEach(rows, id: \.first?.id) { row in
                    HStack(alignment: .top, spacing: .spaceS) {
                        ForEach(row) { NumberTileView(tile: $0) }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
                if tiles.contains(where: { $0.peer != nil }) {
                    PeerMethodButton(classification: profile.classification)
                }
            }
        }
    }
}

private struct NumberTileView: View {
    @ReducesMotion private var reduceMotion
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
                .amountLine()
            if let fraction = tile.fraction {
                ProgressBar(value: filled ? fraction : 0, color: .retroTeal)
                    .animation(reduceMotion ? nil : .chartReveal(0), value: filled)
                    .onAppear { filled = true }
            }
            if let caption = tile.caption {
                Text(verbatim: caption).font(.caption).foregroundStyle(.secondary)
            }
            if let peer = tile.peer {
                PeerBadge(band: peer.band)
                Text(verbatim: peer.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if let source = tile.source {
                Text(verbatim: source).font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(.spaceM)
        .frame(maxWidth: .infinity, minHeight: .profileTileMinHeight, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(.plainRow, in: .rect(cornerRadius: .radiusM))
        .accessibilityElement(children: .combine)
    }
}

struct ProfileThemesSection: View {
    @Environment(ProfileModel.self) private var profile

    var body: some View {
        if !profile.themeLines.isEmpty {
            ProfileBlock(title: Text("Themes"), footer: [profile.themeFootnote]) {
                ForEach(profile.themeLines) { line in
                    HStack(spacing: .spaceM) {
                        Image(systemName: line.theme.symbol)
                            .font(.icon(.s, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: .badgeM, height: .badgeM)
                            .background(
                                Color.secondary.opacity(.opacityTint),
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
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

struct ProfileSalarySection: View {
    @Environment(ProfileModel.self) private var profile

    var body: some View {
        if !profile.salaryLines.isEmpty {
            ProfileBlock(title: Text("Salary")) {
                ForEach(profile.salaryLines) { line in
                    LabeledContent {
                        Text(verbatim: line.value).multilineTextAlignment(.trailing)
                    } label: {
                        Text(verbatim: line.title)
                    }
                }
            }
        }
    }
}
