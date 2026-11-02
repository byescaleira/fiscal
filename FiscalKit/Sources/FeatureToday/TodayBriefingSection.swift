import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct TodayBriefingSection: View {
    @Environment(TodayModel.self) private var today

    var body: some View {
        TodaySection("Summary of the Day", source: today.digestSource) {
            if let lead = today.lead {
                TodayLeadCard(event: lead)
                if !today.others.isEmpty {
                    VStack(spacing: 0) {
                        let others = today.others
                        ForEach(Array(others.enumerated()), id: \.offset) { offset, event in
                            TodayEventRow(event: event)
                            if offset < others.count - 1 {
                                Divider().padding(.leading, .badgeM + .spaceL + .spaceM)
                            }
                        }
                    }
                    .todayCard()
                }
            } else {
                TodayQuietDay()
            }
        }
    }
}

private struct TodayLeadCard: View {
    @Environment(TodayModel.self) private var today
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section
    let event: TodayDigest.Event

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceM) {
            HStack(alignment: .center, spacing: .spaceS) {
                EventKicker(event: event)
                Spacer(minLength: .spaceS)
                if let subject = today.shareSubject(for: event) {
                    Button("Share", systemImage: "square.and.arrow.up") {
                        open(.share(subject), in: section)
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .font(.body.weight(.semibold))
                }
            }
            LeadContent(event: event)
        }
        .padding(.spaceInset)
        .todayCard()
    }
}

private struct LeadContent: View {
    @Environment(TodayModel.self) private var today
    let event: TodayDigest.Event

    var body: some View {
        let route = today.route(for: event)
        RouteButton(route: route) {
            VStack(alignment: .leading, spacing: .spaceM) {
                VStack(alignment: .leading, spacing: .spaceXS) {
                    Text(verbatim: event.title)
                        .font(.titleLarge)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(verbatim: event.summary)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                if let vote = today.leadVote(for: event) {
                    VStack(alignment: .leading, spacing: .spaceS) {
                        HStack(alignment: .bottom) {
                            TallyLine(tally: vote.tally, font: .scoreboardTitle)
                            Spacer(minLength: .spaceS)
                            if let approved = vote.approved { ResultChip(approved: approved) }
                        }
                        VoteTallyChart(tally: vote.tally)
                        Text(verbatim: today.voteLine(vote))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
                if route != nil {
                    HStack(spacing: .space2XS) {
                        Text("See details")
                        Image(systemName: "chevron.forward")
                            .accessibilityHidden(true)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tint)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
    }
}

private struct EventKicker: View {
    @Environment(TodayModel.self) private var today
    let event: TodayDigest.Event

    var body: some View {
        AdaptiveStack(alignment: .center, spacing: .spaceS) {
            Label {
                Text(verbatim: today.kindKicker(event.kind))
            } icon: {
                Image(systemName: today.kindSymbol(event.kind))
            }
            .font(.chipLabel)
            .foregroundStyle(.secondary)
            if let theme = event.themes.first {
                ThemeTag(theme: theme)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct TodayEventRow: View {
    @Environment(TodayModel.self) private var today
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section
    let event: TodayDigest.Event

    var body: some View {
        let route = today.route(for: event)
        RouteButton(route: route) {
            HStack(alignment: .top, spacing: .spaceM) {
                ThemeTile(symbol: today.eventSymbol(event))
                VStack(alignment: .leading, spacing: .space2XS) {
                    EventKicker(event: event)
                    Text(verbatim: event.title)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(verbatim: event.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                Spacer(minLength: 0)
                if route != nil {
                    Image(systemName: "chevron.forward")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
            }
            .padding(.spaceL)
        }
        .accessibilityElement(children: .combine)
        .contextMenu {
            if let subject = today.shareSubject(for: event) {
                Button("Share", systemImage: "square.and.arrow.up") {
                    open(.share(subject), in: section)
                }
            }
        }
    }
}

private struct TodayQuietDay: View {
    var body: some View {
        HStack(alignment: .top, spacing: .spaceM) {
            ThemeTile(symbol: "newspaper")
            VStack(alignment: .leading, spacing: .space2XS) {
                Text("Nothing new yet").font(.headline)
                Text("Votes, sessions and new laws show up here as they happen.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.spaceL)
        .todayCard()
        .accessibilityElement(children: .combine)
    }
}
