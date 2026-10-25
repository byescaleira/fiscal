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
                    RaceCountLine(
                        attributes: context.attributes, state: context.state,
                        isStale: context.isStale)
                }
            } compactLeading: {
                if let first = rows.first { CompactStanding(row: first) }
            } compactTrailing: {
                if rows.count > 1 { CompactStanding(row: rows[1]) }
            } minimal: {
                Image(systemName: "chart.bar.xaxis")
                    .foregroundStyle(Color.retroTeal)
                    .accessibilityLabel(
                        Text(verbatim: RaceWidgetText.counted(context.state.sectionsPercent)))
            }
            .keylineTint(Color.retroTeal)
            .widgetURL(URL(string: "fiscal://home"))
        }
    }
}

private struct RaceLockScreen: View {
    let context: ActivityViewContext<RaceActivityAttributes>

    var body: some View {
        let rows = context.state.rows(with: context.attributes.candidates)
        VStack(alignment: .leading, spacing: .spaceM) {
            RaceCountLine(
                attributes: context.attributes, state: context.state, isStale: context.isStale)
            ForEach(rows) { LockScreenRow(row: $0) }
            Text(verbatim: RaceWidgetText.source(state: context.state, isStale: context.isStale))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.spaceL)
        .fontDesign(.rounded)
    }
}

private struct RaceCountLine: View {
    let attributes: RaceActivityAttributes
    let state: RaceActivityState
    let isStale: Bool

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
            ProgressBar(value: state.sectionsPercent / 100, color: .retroTeal)
        }
        .opacity(isStale ? 0.6 : 1)
        .accessibilityElement(children: .combine)
    }

    private var countText: String {
        state.final
            ? String(appLocalized: "Final result") : RaceWidgetText.counted(state.sectionsPercent)
    }
}

enum RaceWidgetText {
    static func source(state: RaceActivityState, isStale: Bool) -> String {
        let time = RaceText.time(state.updatedDate)
        return isStale
            ? String(appLocalized: "No update since \(time) · TSE")
            : String(appLocalized: "TSE file from \(time)")
    }

    static func counted(_ percent: Double) -> String {
        String(appLocalized: "\(RaceText.percent(percent)) counted")
    }

    static func row(_ row: RaceActivityRow) -> String {
        let votes = String(appLocalized: "\(RaceText.votes(row.votes)) votes")
        let base = "\(row.name), \(row.party), \(RaceText.percent(row.percent)), \(votes)"
        return row.elected ? "\(base), \(String(appLocalized: "Elected"))" : base
    }
}

private struct LockScreenRow: View {
    let row: RaceActivityRow

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: .space2XS) {
                    Text(verbatim: row.name)
                        .font(.headline)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    if row.elected {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(Color.retroTeal)
                    }
                }
                Text(verbatim: row.party).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: .spaceS)
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: RaceWidgetText.row(row)))
    }
}

private struct IslandCandidate: View {
    let row: RaceActivityRow
    let alignment: HorizontalAlignment

    var body: some View {
        VStack(alignment: alignment, spacing: 0) {
            HStack(spacing: .space2XS) {
                if row.elected {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(Color.retroTeal)
                }
                Text(verbatim: row.name).font(.caption.weight(.semibold)).lineLimit(1)
            }
            Text(verbatim: RaceText.percent(row.percent))
                .font(.title3.weight(.bold))
                .monospacedDigit()
        }
        .padding(.horizontal, .space2XS)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: RaceWidgetText.row(row)))
    }
}

private struct CompactStanding: View {
    let row: RaceActivityRow

    var body: some View {
        Text(verbatim: row.compactText)
            .font(.caption.weight(.bold))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .accessibilityLabel(Text(verbatim: RaceWidgetText.row(row)))
    }
}
