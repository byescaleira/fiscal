import ActivityKit
import FiscalDesignSystem
import FiscalDomain
import SwiftUI
import WidgetKit

struct RaceLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RaceActivityAttributes.self) { context in
            RaceLockScreen(context: context)
                .activityBackgroundTint(nil)
                .widgetURL(URL(string: "fiscal://home"))
        } dynamicIsland: { context in
            let rows = context.state.rows(with: context.attributes.candidates)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    if let first = rows.first { IslandCandidate(row: first, alignment: .leading) }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if rows.count > 1 { IslandCandidate(row: rows[1], alignment: .trailing) }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    RaceCountLine(attributes: context.attributes, state: context.state)
                }
            } compactLeading: {
                if let first = rows.first { CompactStanding(row: first) }
            } compactTrailing: {
                if rows.count > 1 { CompactStanding(row: rows[1]) }
            } minimal: {
                Text(verbatim: RaceText.shortPercent(context.state.sectionsPercent))
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
            }
            .widgetURL(URL(string: "fiscal://home"))
        }
    }
}

private struct RaceLockScreen: View {
    let context: ActivityViewContext<RaceActivityAttributes>

    var body: some View {
        let rows = context.state.rows(with: context.attributes.candidates)
        VStack(alignment: .leading, spacing: .spaceM) {
            RaceCountLine(attributes: context.attributes, state: context.state)
            ForEach(rows) { LockScreenRow(row: $0) }
        }
        .padding(.spaceL)
        .fontDesign(.rounded)
    }
}

private struct RaceCountLine: View {
    let attributes: RaceActivityAttributes
    let state: RaceActivityState

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceXS) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: RaceText.title(office: attributes.office, uf: attributes.uf))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(verbatim: countText)
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
            }
            ProgressBar(value: state.sectionsPercent / 100, color: .accentColor)
        }
    }

    private var countText: String {
        if state.final { return String(appLocalized: "Final result") }
        return String(appLocalized: "\(RaceText.percent(state.sectionsPercent)) counted")
    }
}

private struct LockScreenRow: View {
    let row: RaceActivityRow

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            HStack(spacing: .space2XS) {
                Text(verbatim: row.name).font(.headline).lineLimit(1)
                if row.elected {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.tint)
                }
            }
            Text(verbatim: row.party).font(.caption).foregroundStyle(.secondary)
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text(verbatim: RaceText.percent(row.percent))
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                Text(verbatim: RaceText.compactVotes(row.votes))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct IslandCandidate: View {
    let row: RaceActivityRow
    let alignment: HorizontalAlignment

    var body: some View {
        VStack(alignment: alignment, spacing: 0) {
            HStack(spacing: .space2XS) {
                if row.elected { Image(systemName: "checkmark.seal.fill").foregroundStyle(.tint) }
                Text(verbatim: row.name).font(.caption.weight(.semibold)).lineLimit(1)
            }
            Text(verbatim: RaceText.percent(row.percent))
                .font(.title3.weight(.bold))
                .monospacedDigit()
        }
        .padding(.horizontal, .space2XS)
    }
}

private struct CompactStanding: View {
    let row: RaceActivityRow

    var body: some View {
        Text(verbatim: "\(row.number) \(RaceText.shortPercent(row.percent))")
            .font(.caption.weight(.bold))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}
