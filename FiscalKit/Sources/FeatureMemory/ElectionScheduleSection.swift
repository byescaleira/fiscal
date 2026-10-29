import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct ElectionScheduleSection: View {
    @Environment(MemoryModel.self) private var memory

    var body: some View {
        let elections = memory.schedule
        Section {
            ForEach(elections) { election in
                ScheduleRow(election: election, isLast: election.id == elections.last?.id)
            }
        } header: {
            Text("Election calendar").sectionTitle()
        } footer: {
            Text("Source: TSE election calendar. Live counting from the TSE on election days.")
        }
    }
}

private struct ScheduleRow: View {
    @Environment(\.appTint) private var tint
    let election: ScheduledElection
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: .spaceL) {
            VStack(spacing: .spaceXS) {
                Text(verbatim: String(election.year))
                    .font(.scoreboardTitle)
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
                ForEach(election.rounds) { ScheduleRoundLine(round: $0) }
                if election.isCurrent {
                    CurrentElectionDetail()
                } else if election.isFinished {
                    ScheduleResultLink(year: election.year)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, .spaceXS)
    }
}

private struct ScheduleRoundLine: View {
    let round: ScheduledRound

    var body: some View {
        HStack(spacing: .spaceS) {
            StatusCircle(round.statusText, symbol: round.symbol, color: round.color)
            Text(verbatim: round.title)
                .font(.subheadline.weight(.semibold))
            Text(verbatim: round.status == .today ? round.statusText : round.shortDate)
                .font(.subheadline)
                .foregroundStyle(round.status == .today ? round.color : .secondary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            Text(verbatim: "\(round.title), \(round.shortDate), \(round.statusText)"))
    }
}

private struct ScheduleResultLink: View {
    @Environment(MemoryModel.self) private var memory
    let year: Int

    var body: some View {
        if memory.presidential.contains(where: { $0.year == year }) {
            RouteLink(.pastElection(year: year)) {
                Text("See the result, state by state")
                    .font(.buttonLabel)
                    .foregroundStyle(.tint)
            }
        }
    }
}

private struct CurrentElectionDetail: View {
    @Environment(MemoryModel.self) private var memory
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section
    @State private var isShown = false

    var body: some View {
        if let counted = memory.liveCounted {
            Button {
                open(.races, in: section)
            } label: {
                VStack(alignment: .leading, spacing: .space2XS) {
                    Text("Polls counted: \(PublicFormat.percent(counted))")
                        .font(.footnote.weight(.semibold))
                        .monospacedDigit()
                    ProgressBar(value: isShown ? counted : 0, color: .scoreboardAccent)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint(Text("Opens the live count"))
            .animation(reduceMotion ? nil : .smooth(duration: 1), value: isShown)
            .onAppear { isShown = true }
        }
        if !memory.awaiting.isEmpty {
            NavigationLink {
                AwaitingScreen().environment(memory)
            } label: {
                Label(
                    "Elected in 2026, awaiting inauguration: \(memory.awaiting.count)",
                    systemImage: "person.crop.circle.badge.clock"
                )
                .font(.buttonLabel)
            }
        }
    }
}

extension ScheduledRound {
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
}

private struct AwaitingScreen: View {
    @Environment(MemoryModel.self) private var memory

    var body: some View {
        List {
            Group {
                Section {
                    ForEach(memory.awaiting, id: \.slug) { person in
                        RouteLink(.person(slug: person.slug)) {
                            HStack(spacing: .spaceM) {
                                PersonPortrait(
                                    slug: person.slug, name: person.name, party: person.party,
                                    size: .badgeL)
                                VStack(alignment: .leading, spacing: .spaceHairline) {
                                    Text(verbatim: person.name).font(.rowTitle)
                                    Text(
                                        verbatim:
                                            "\(person.office.title) · \(person.uf.uppercased())"
                                    )
                                    .font(.rowDetail)
                                    .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: .spaceS)
                                PartyMark(person.party)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                } footer: {
                    Text("Alphabetical order. Source: TSE, candidates elected in 2026.")
                }
            }
            .surfaceRows()
        }
        .listSurface()
        .emphasisTitle("Awaiting inauguration")
    }
}
