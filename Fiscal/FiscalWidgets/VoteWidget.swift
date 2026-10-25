import FiscalDomain
import SwiftUI
import WidgetKit

struct VoteEntry: TimelineEntry {
    let date: Date
    let state: WidgetState<VoteDeck>
    var isSample = false

    static var sample: VoteEntry {
        let vote = VoteSummary(
            id: "sample", house: .camara, date: CalendarDay(.now), time: "18:00",
            proposition: "PL 0000/2026", kind: nil,
            summary: "Cria um cadastro nacional de doadores de medula óssea.",
            plainSummary: nil, themes: [.health], result: nil, approved: true, nominal: true,
            tally: VoteSummary.Tally(yes: 300, no: 100, others: 10))
        let board = VoteBoard(vote)
        return VoteEntry(
            date: .now, state: .ready(VoteDeck(headline: board, earlier: [board, board, board])),
            isSample: true)
    }
}

struct VoteProvider: TimelineProvider {
    func placeholder(in context: Context) -> VoteEntry {
        .sample
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (VoteEntry) -> Void) {
        let isPreview = context.isPreview
        Task {
            let entry = await Self.load()
            completion(isPreview && entry.state.value == nil ? .sample : entry)
        }
    }

    func getTimeline(
        in context: Context, completion: @escaping @Sendable (Timeline<VoteEntry>) -> Void
    ) {
        Task {
            let entry = await Self.load()
            let next =
                switch entry.state {
                case .unavailable: WidgetSchedule.retry(after: entry.date)
                case .ready, .empty, .needsPlace:
                    WidgetSchedule.nextVotesRefresh(after: entry.date, calendar: .current)
                }
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    static func load() async -> VoteEntry {
        guard let feed = WidgetSource.feed() else {
            return VoteEntry(date: .now, state: .unavailable(offline: false))
        }
        return VoteEntry(date: .now, state: await feed.votes())
    }
}

struct VoteWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "fiscal.vote", provider: VoteProvider()) { entry in
            VoteWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetStyle.voteBackground }
                .widgetURL(entry.state.value?.headline.url ?? IntegrationLink.votes)
        }
        .configurationDisplayName("Vote of the Day")
        .description("The latest vote in Congress, with the Yes and No score and the result.")
        .supportedFamilies(voteFamilies)
    }

    private var voteFamilies: [WidgetFamily] {
        [
            .systemSmall, .systemMedium, .systemLarge, .accessoryRectangular,
            .accessoryInline, .accessoryCircular,
        ]
    }
}

struct VoteWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: VoteEntry

    var body: some View {
        content
            .fontDesign(.rounded)
            .redacted(reason: entry.isSample ? .placeholder : [])
    }

    @ViewBuilder
    private var content: some View {
        switch entry.state {
        case .ready(let deck):
            ready(deck)
        case .empty, .needsPlace:
            message(
                symbol: "checkmark.square", title: "No votes yet",
                detail: "Fiscal shows the latest vote in Congress as soon as it's published.")
        case .unavailable(let offline):
            message(
                symbol: offline ? "wifi.slash" : "exclamationmark.icloud",
                title: "Couldn't load the votes",
                detail: "Fiscal tries again in a while. Open the app to see the last saved data.")
        }
    }

    @ViewBuilder
    private func ready(_ deck: VoteDeck) -> some View {
        switch family {
        case .accessoryRectangular: VoteRectangular(board: deck.headline)
        case .accessoryInline: VoteInline(board: deck.headline)
        case .accessoryCircular: VoteCircular(board: deck.headline)
        case .systemSmall: VoteSmall(board: deck.headline)
        case .systemLarge: VoteLarge(deck: deck)
        default: VoteMedium(board: deck.headline)
        }
    }

    @ViewBuilder
    private func message(symbol: String, title: LocalizedStringKey, detail: LocalizedStringKey)
        -> some View
    {
        switch family {
        case .accessoryRectangular, .accessoryInline, .accessoryCircular:
            AccessoryMessage(symbol: symbol, title: title)
        default:
            WidgetMessage(symbol: symbol, title: title, detail: detail)
        }
    }
}
