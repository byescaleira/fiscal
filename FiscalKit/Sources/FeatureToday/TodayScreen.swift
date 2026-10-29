import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public struct TodayScreen<RaceHero: View>: View {
    @Environment(TodayModel.self) private var today
    @Environment(SessionModel.self) private var session
    private let raceHero: (Race) -> RaceHero

    public init(@ViewBuilder raceHero: @escaping (Race) -> RaceHero) {
        self.raceHero = raceHero
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .spaceXL) {
                TodayMasthead()
                if let board = today.liveBoard {
                    TodayRaceHero(board: board) { raceHero(board.race) }
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
        .background(.plainBackground)
        .emphasisTitle("Today")
        .toolbar { TodayToolbar() }
        .refreshable { await today.load() }
        .task {
            await today.load()
            await today.watchRaces()
        }
        .onChange(of: session.generation) { Task { await today.load() } }
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
            CardGrid(minimumWidth: .cardColumn, spacing: .spaceXL) {
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

    var body: some View {
        Chip(today.dateKicker, color: tint, shape: .capsule)
            .accessibilityLabel(Text(verbatim: today.dateLine))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TodayToolbar: ToolbarContent {
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section

    var body: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button("Who You Support", systemImage: "heart") { open(.lens, in: section) }
                .tint(Color.primary)
        }
        FixedToolbarSpacer(placement: .primaryAction)
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
        VStack(spacing: .spaceM) {
            SymbolBadge(error.symbol, color: .secondary, size: .badgeXL)
            Text(verbatim: today.failureTitle(error))
                .font(.titleMedium)
            Text(verbatim: error.message)
                .font(.body)
                .foregroundStyle(.secondary)
            Button("Try Again") { Task { await today.load() } }
                .primaryButton()
                .padding(.top, .spaceS)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, .spaceM)
    }
}

private struct TodayPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: .spaceXL) {
            VStack(alignment: .leading, spacing: .spaceM) {
                Text(verbatim: "Vote · Taxes and public spending")
                    .font(.chipLabel)
                Text(verbatim: "The Chamber voted a bill about the income tax table today")
                    .font(.titleMedium)
                Text(verbatim: "A short summary in plain language comes right below the title.")
                    .font(.body)
                HStack(spacing: .spaceL) {
                    Text(verbatim: "412").font(.scoreboardTitle)
                    Text(verbatim: "61").font(.scoreboardTitle)
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
