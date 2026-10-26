import FiscalDesignSystem
import FiscalDomain
import SwiftUI
import WidgetKit

struct HighlightEntry: TimelineEntry {
    let date: Date
    let state: WidgetState<HighlightDeck>
    var isSample = false

    static var sample: HighlightEntry {
        let board = HighlightBoard(
            id: "sample", kind: .action,
            title: "Cria o cadastro nacional de doadores de medula óssea e muda a lei do SUS.",
            subtitle: "PL 0000/2026 · Nome Sobrenome", weight: 90, day: CalendarDay(.now),
            route: "", personName: "Nome Sobrenome", personSlug: "sample", party: "")
        return HighlightEntry(
            date: .now, state: .ready(HighlightDeck(lead: board, others: [board, board, board])),
            isSample: true)
    }
}

struct HighlightProvider: TimelineProvider {
    func placeholder(in context: Context) -> HighlightEntry {
        .sample
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (HighlightEntry) -> Void)
    {
        let isPreview = context.isPreview
        Task {
            let entry = await Self.load()
            completion(isPreview && entry.state.value == nil ? .sample : entry)
        }
    }

    func getTimeline(
        in context: Context, completion: @escaping @Sendable (Timeline<HighlightEntry>) -> Void
    ) {
        Task {
            let entry = await Self.load()
            let next = WidgetSchedule.nextHighlightsRefresh(after: entry.date)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    static func load() async -> HighlightEntry {
        guard let feed = WidgetSource.feed() else {
            return HighlightEntry(date: .now, state: .unavailable(offline: false))
        }
        return HighlightEntry(date: .now, state: await feed.highlights())
    }
}

struct HighlightWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "fiscal.highlight", provider: HighlightProvider()) { entry in
            HighlightWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color.groupedRow }
                .widgetURL(entry.state.value?.lead.url ?? IntegrationLink.today)
        }
        .configurationDisplayName("Highlight of the Moment")
        .description("What weighs most in politics now, with the official text and who did it.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline,
        ])
    }
}

struct HighlightWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: HighlightEntry

    var body: some View {
        content
            .fontDesign(.rounded)
            .partyMarksStill()
            .redacted(reason: entry.isSample ? .placeholder : [])
    }

    @ViewBuilder
    private var content: some View {
        switch entry.state {
        case .ready(let deck):
            ready(deck)
        case .empty, .needsPlace:
            message(
                symbol: "scalemass", title: "No highlights yet",
                detail: "Fiscal shows what weighs most as soon as the day's data is published.")
        case .unavailable(let offline):
            message(
                symbol: offline ? "wifi.slash" : "exclamationmark.icloud",
                title: "Couldn't load the highlights",
                detail: "Fiscal tries again in a while. Open the app to see the last saved data.")
        }
    }

    @ViewBuilder
    private func ready(_ deck: HighlightDeck) -> some View {
        switch family {
        case .accessoryRectangular: HighlightRectangular(board: deck.lead)
        case .accessoryInline: HighlightInline(board: deck.lead)
        case .systemSmall: HighlightSmall(board: deck.lead)
        case .systemLarge: HighlightLarge(deck: deck)
        default: HighlightMedium(board: deck.lead)
        }
    }

    @ViewBuilder
    private func message(symbol: String, title: LocalizedStringKey, detail: LocalizedStringKey)
        -> some View
    {
        switch family {
        case .accessoryRectangular, .accessoryInline:
            AccessoryMessage(symbol: symbol, title: title)
        default:
            HighlightMessage(symbol: symbol, title: title, detail: detail)
        }
    }
}

private struct HighlightMessage: View {
    let symbol: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceXS) {
            Image(systemName: symbol)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.secondary)
                .widgetAccentable()
            Spacer(minLength: 0)
            Text(title)
                .font(.headline)
                .lineLimit(2)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
