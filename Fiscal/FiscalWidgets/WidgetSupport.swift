import FiscalData
import FiscalDesignSystem
import FiscalDomain
import SwiftUI
import WidgetKit

enum WidgetSource {
    static func feed() -> WidgetFeed? {
        #if DEBUG
            if let scenario = PublicDataScenario.named(HomePlace().scenario) {
                return WidgetFeed(service: ShowcasePublicData(scenario: scenario))
            }
        #endif
        return PublicDataClient.fromBundle().map { WidgetFeed(service: $0) }
    }
}

enum WidgetStyle {
    static let board = Color.scoreboard
    static let yes = Color.retroOlive
    static let no = Color.retroRust
    static let primary = Color.white
    static let secondary = Color.white.opacity(.opacityStrong)
    static let track = Color.white.opacity(.opacityTint)
    static let veil = Color.black.opacity(.opacityTint)

    static var voteBackground: some View {
        ZStack {
            LinearGradient(
                colors: [yes, board, no], startPoint: .leading, endPoint: .trailing)
            veil
        }
    }
}

struct TallyStrip: View {
    let board: VoteBoard

    var body: some View {
        TallyBar(
            segments: [
                .init(id: "yes", value: board.yesShare, color: WidgetStyle.primary),
                .init(id: "no", value: board.noShare, color: WidgetStyle.secondary),
                .init(id: "others", value: board.othersShare, color: WidgetStyle.track),
            ], height: .tallyStrip
        )
        .widgetAccentable()
    }
}

struct LastPlayLine: View {
    let title: String
    let source: String
    var lines = 2

    var body: some View {
        HStack(spacing: .spaceS) {
            Capsule()
                .fill(WidgetStyle.primary)
                .frame(width: .lastPlayRule)
                .widgetAccentable()
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(WidgetStyle.primary)
                    .lineLimit(lines)
                    .minimumScaleFactor(.widgetTextShrink)
                Text(verbatim: source)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(WidgetStyle.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(.widgetTextShrink)
            }
            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }
}

struct WidgetMessage: View {
    let symbol: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceXS) {
            Image(systemName: symbol)
                .font(.title2.weight(.semibold))
                .foregroundStyle(WidgetStyle.primary)
                .widgetAccentable()
            Spacer(minLength: 0)
            Text(title)
                .font(.headline)
                .foregroundStyle(WidgetStyle.primary)
                .lineLimit(2)
            Text(detail)
                .font(.caption)
                .foregroundStyle(WidgetStyle.secondary)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct AccessoryMessage: View {
    let symbol: String
    let title: LocalizedStringKey

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .lineLimit(2)
    }
}
