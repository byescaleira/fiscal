import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public struct TodayScreen: View {
    @Environment(TodayModel.self) private var today

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .spaceXL) {
                TodayMasthead()
                if let board = today.liveBoard {
                    TodayRaceHero(board: board)
                        .transition(.opacity)
                }
                TodayHighlightSection()
                TodayBody()
            }
            .padding(.horizontal, .spaceL)
            .padding(.bottom, .space2XL)
            .frame(maxWidth: .readableColumn * 2)
            .frame(maxWidth: .infinity)
        }
        .background(.groupedBackground)
        .fontDesign(.rounded)
        .navigationTitle("Today")
        .toolbar { TodayToolbar() }
        .refreshable { await today.load() }
        .task {
            await today.load()
            await today.watchRaces()
        }
    }
}

private struct TodayBody: View {
    @Environment(TodayModel.self) private var today

    var body: some View {
        if today.hasLoadedDigest {
            if let notice = today.notice {
                TodayNotice(text: notice.text, symbol: notice.symbol)
            }
            TodayBriefingSection()
            LazyVGrid(
                columns: [
                    GridItem(
                        .adaptive(minimum: .cardColumn), spacing: .spaceXL, alignment: .top)
                ],
                alignment: .leading, spacing: .spaceXL
            ) {
                TodayCongressSection()
                TodayRepresentativesSection()
                TodayRecentVotesSection()
            }
        } else if let error = today.phase.error {
            TodayFailure(error: error)
        } else {
            TodayPlaceholder()
        }
    }
}

private struct TodayMasthead: View {
    @Environment(TodayModel.self) private var today
    @Environment(\.appTint) private var tint
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            Text(verbatim: today.dateLine.uppercased())
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(tint)
                .accessibilityLabel(Text(verbatim: today.dateLine))
            if today.showsLensBadge {
                Button {
                    open(.lens, in: section)
                } label: {
                    LensBadge()
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text("Shows what the lens changes and lets you switch it"))
            }
            if let line = today.lensLine {
                Text(verbatim: line)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if today.hasCheckedLens, today.lens == nil {
                TodayLensInvite()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TodayLensInvite: View {
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section
    @Environment(\.appTint) private var tint

    var body: some View {
        Button {
            open(.lens, in: section)
        } label: {
            HStack(spacing: .spaceM) {
                SymbolBadge("eyeglasses", color: tint, size: .badgeL)
                VStack(alignment: .leading, spacing: .spaceHairline) {
                    Text("Put your topics first").font(.rowTitle)
                    Text("Your lens changes the order, never the facts. It stays on this iPhone.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: .spaceS)
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.spaceL)
            .todayCard()
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .padding(.top, .spaceS)
    }
}

private struct TodayToolbar: ToolbarContent {
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section

    var body: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button("Lens", systemImage: "eyeglasses") { open(.lens, in: section) }
                .tint(Color.primary)
        }
        ToolbarItem(placement: .primaryAction) {
            #if os(macOS)
                SettingsLink {
                    Label("Settings", systemImage: "gearshape")
                }
            #else
                Button("Settings", systemImage: "gearshape") { open(.settings, in: section) }
                    .tint(Color.primary)
            #endif
        }
    }
}

private struct TodayFailure: View {
    @Environment(TodayModel.self) private var today
    let error: PublicDataError

    var body: some View {
        VStack(spacing: .spaceL) {
            SymbolBadge(error.symbol, color: .secondary, size: .badgeXL)
            VStack(spacing: .spaceXS) {
                Text("Couldn't load the summary of the day")
                    .font(.headline)
                Text(verbatim: error.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            Button("Try Again") { Task { await today.load() } }
                .primaryButton()
        }
        .padding(.spaceXL)
        .todayCard()
    }
}

private struct TodayPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: .spaceXL) {
            VStack(alignment: .leading, spacing: .spaceM) {
                Text(verbatim: "Vote · Taxes and public spending")
                    .font(.caption2.weight(.heavy))
                Text(verbatim: "The Chamber voted a bill about the income tax table today")
                    .font(.titleMedium)
                Text(verbatim: "A short summary in plain language comes right below the title.")
                    .font(.body)
                HStack(spacing: .spaceL) {
                    Text(verbatim: "412").font(.scoreboardNumber)
                    Text(verbatim: "61").font(.scoreboardNumber)
                }
            }
            .padding(.spaceInset)
            .todayCard()
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: .spaceM) {
                    ThemeTile(symbol: "building.columns")
                    VStack(alignment: .leading, spacing: .space2XS) {
                        Text(verbatim: "Senate session on Tuesday").font(.headline)
                        Text(verbatim: "On the agenda, savings for students.").font(.subheadline)
                    }
                }
                .padding(.spaceL)
                .todayCard()
            }
        }
        .redacted(reason: .placeholder)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Loading the summary of the day"))
    }
}
