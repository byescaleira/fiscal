import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct ElectionsSection: View {
    @Environment(SearchModel.self) private var search

    var body: some View {
        Section {
            ForEach(search.elections) { election in
                ElectionRow(election: election, isLast: election.id == search.elections.last?.id)
            }
        } header: {
            Text("Elections").sectionTitle()
        } footer: {
            Text(
                "Source: TSE election calendar. Mayors and city councillors come after version 1.0."
            )
        }
    }
}

private struct ElectionRow: View {
    @Environment(\.appTint) private var tint
    let election: Election
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: .spaceL) {
            VStack(spacing: .spaceXS) {
                Text(verbatim: String(election.year))
                    .font(.scoreboardNumber)
                    .foregroundStyle(election.isCurrent ? tint : Color.primary)
                    .monospacedDigit()
                if !isLast {
                    Capsule()
                        .fill(.tertiary)
                        .frame(width: .spaceHairline)
                        .frame(maxHeight: .infinity)
                        .accessibilityHidden(true)
                }
            }
            VStack(alignment: .leading, spacing: .spaceS) {
                Text(verbatim: election.title).font(.rowTitle)
                Text("President, governors, Senate and deputies")
                    .font(.rowDetail)
                    .foregroundStyle(.secondary)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: .spaceS) {
                        ForEach(election.rounds) { RoundChip(round: $0) }
                    }
                    VStack(alignment: .leading, spacing: .spaceS) {
                        ForEach(election.rounds) { RoundChip(round: $0) }
                    }
                }
                if election.isCurrent {
                    CurrentElectionDetail()
                } else {
                    Text("Who was elected appears in each profile's history, with the votes.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, .spaceXS)
    }
}

private struct RoundChip: View {
    let round: ElectionRound

    var body: some View {
        HStack(spacing: .space2XS) {
            Image(systemName: round.symbol)
            Text(verbatim: round.text)
        }
        .font(.chipLabel)
        .foregroundStyle(round.color)
        .padding(.horizontal, .spaceS)
        .padding(.vertical, .space2XS)
        .background(round.color.opacity(.opacityTint), in: .capsule)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(round.accessibilityText)
    }
}

private struct CurrentElectionDetail: View {
    @Environment(SearchModel.self) private var search
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShown = false

    var body: some View {
        if let live = search.liveCount {
            VStack(alignment: .leading, spacing: .space2XS) {
                Text("Polls counted: \(PublicFormat.percent(live.counted))")
                    .font(.footnote.weight(.semibold))
                    .monospacedDigit()
                ProgressBar(value: isShown ? live.counted : 0, color: .scoreboardAccent)
            }
            .accessibilityElement(children: .combine)
            .animation(reduceMotion ? nil : .smooth, value: isShown)
            .onAppear { isShown = true }
        }
        if search.electedAwaiting > 0 {
            Button {
                search.apply(.electedAwaiting)
            } label: {
                Label(
                    "Elected in 2026, awaiting inauguration: \(search.electedAwaiting)",
                    systemImage: "person.crop.circle.badge.clock"
                )
                .font(.buttonLabel)
            }
            .buttonStyle(.borderless)
        }
    }
}

extension ElectionRound {
    var text: String {
        status == .today
            ? "\(title) · \(String(appLocalized: "Today"))" : "\(title) · \(shortDate)"
    }

    var symbol: String {
        switch status {
        case .past: "checkmark"
        case .today: "dot.radiowaves.left.and.right"
        case .upcoming: "calendar"
        }
    }

    var color: Color {
        switch status {
        case .past: .secondary
        case .today: .retroRust
        case .upcoming: .retroDenim
        }
    }

    var accessibilityText: String {
        switch status {
        case .past: String(appLocalized: "\(text), done")
        case .today: String(appLocalized: "\(text), today")
        case .upcoming: String(appLocalized: "\(text), upcoming")
        }
    }
}
