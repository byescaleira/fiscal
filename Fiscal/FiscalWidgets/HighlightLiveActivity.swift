import ActivityKit
import FiscalDesignSystem
import FiscalDomain
import SwiftUI
import WidgetKit

struct HighlightLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HighlightActivityAttributes.self) { context in
            let board = context.attributes.board(weight: context.state.weight)
            HighlightLockScreen(board: board, isStale: context.isStale)
                .activityBackgroundTint(nil)
                .widgetURL(board.url)
        } dynamicIsland: { context in
            let board = context.attributes.board(weight: context.state.weight)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HighlightKicker(board: board)
                        .padding(.leading, .space2XS)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    HighlightWeightText(board: board)
                        .padding(.trailing, .space2XS)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: .spaceS) {
                        Text(verbatim: board.title)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        HighlightWho(board: board, showsPortrait: false)
                    }
                    .padding(.horizontal, .space2XS)
                    .fontDesign(.rounded)
                    .partyMarksStill()
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(verbatim: board.accessibilityText))
                }
            } compactLeading: {
                Image(systemName: "scalemass")
                    .foregroundStyle(RaceStyle.accent)
                    .accessibilityLabel(Text(verbatim: board.kindTitle))
            } compactTrailing: {
                Text(verbatim: "\(board.weight)")
                    .font(.caption.weight(.heavy))
                    .monospacedDigit()
                    .foregroundStyle(RaceStyle.accent)
                    .accessibilityLabel(Text(verbatim: board.weightText))
            } minimal: {
                Image(systemName: "scalemass")
                    .foregroundStyle(RaceStyle.accent)
                    .accessibilityLabel(Text(verbatim: board.weightText))
            }
            .keylineTint(RaceStyle.accent)
            .widgetURL(board.url)
        }
    }
}

private struct HighlightLockScreen: View {
    let board: HighlightBoard
    let isStale: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            HStack(alignment: .firstTextBaseline, spacing: .spaceS) {
                Text("HIGHLIGHT")
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, .spaceS)
                    .padding(.vertical, .space2XS)
                    .background(RaceStyle.track, in: .capsule)
                HighlightKicker(board: board)
                Spacer(minLength: .spaceS)
                HighlightWeightText(board: board)
            }
            Text(verbatim: board.title)
                .font(.headline)
                .lineLimit(3)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)
            HighlightWho(board: board)
        }
        .padding(.horizontal, .spaceXL)
        .padding(.vertical, .spaceL)
        .frame(maxWidth: .infinity)
        .fontDesign(.rounded)
        .partyMarksStill()
        .opacity(isStale ? .opacityStrong : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: board.accessibilityText))
    }
}
