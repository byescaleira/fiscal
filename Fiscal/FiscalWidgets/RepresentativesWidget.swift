import FiscalDomain
import SwiftUI
import WidgetKit

struct RepresentativesEntry: TimelineEntry {
    let date: Date
    let state: WidgetState<RepresentativesDigest>
    var isSample = false

    static var sample: RepresentativesEntry {
        let offices: [Office] = [.governor, .senator, .senator, .senator]
        let people = offices.enumerated().map { index, office in
            PersonCard(
                slug: "sample-\(index)", name: "Nome Sobrenome", office: office, uf: "sp",
                party: "", photo: nil, status: .inOffice)
        }
        let place = PlaceRepresentatives(
            uf: "sp", name: HomePlace.name(of: "sp"),
            groups: [
                RepresentativeGroup(level: .state, office: .governor, title: "", people: people)
            ], sources: [])
        return RepresentativesEntry(
            date: .now, state: .ready(RepresentativesDigest(place)), isSample: true)
    }
}

struct RepresentativesProvider: TimelineProvider {
    func placeholder(in context: Context) -> RepresentativesEntry {
        .sample
    }

    func getSnapshot(
        in context: Context, completion: @escaping @Sendable (RepresentativesEntry) -> Void
    ) {
        let isPreview = context.isPreview
        Task {
            let entry = await Self.load()
            completion(isPreview && entry.state.value == nil ? .sample : entry)
        }
    }

    func getTimeline(
        in context: Context,
        completion: @escaping @Sendable (Timeline<RepresentativesEntry>) -> Void
    ) {
        Task {
            let entry = await Self.load()
            let next =
                switch entry.state {
                case .unavailable: WidgetSchedule.retry(after: entry.date)
                case .ready, .empty, .needsPlace:
                    WidgetSchedule.nextRepresentativesRefresh(after: entry.date)
                }
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    static func load() async -> RepresentativesEntry {
        let uf = HomePlace().uf
        guard uf != nil else { return RepresentativesEntry(date: .now, state: .needsPlace) }
        guard let feed = WidgetSource.feed() else {
            return RepresentativesEntry(date: .now, state: .unavailable(offline: false))
        }
        return RepresentativesEntry(date: .now, state: await feed.representatives(uf: uf))
    }
}

struct RepresentativesWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "fiscal.representatives", provider: RepresentativesProvider()) {
            entry in
            RepresentativesWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetStyle.board }
                .widgetURL(IntegrationLink.mine)
        }
        .configurationDisplayName("My Representatives")
        .description("Who represents your state, with a tap to each profile.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct RepresentativesWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RepresentativesEntry

    var body: some View {
        content
            .fontDesign(.rounded)
            .redacted(reason: entry.isSample ? .placeholder : [])
    }

    @ViewBuilder
    private var content: some View {
        switch entry.state {
        case .ready(let digest):
            if family == .systemSmall {
                RepresentativesSmall(digest: digest)
            } else {
                RepresentativesMedium(digest: digest)
            }
        case .needsPlace:
            WidgetMessage(
                symbol: "map", title: "Pick your state",
                detail: "Open Fiscal and choose your state in Mine.")
        case .empty:
            WidgetMessage(
                symbol: "person.2", title: "No representatives yet",
                detail: "This state's list isn't published yet.")
        case .unavailable(let offline):
            WidgetMessage(
                symbol: offline ? "wifi.slash" : "exclamationmark.icloud",
                title: "Couldn't load your representatives",
                detail: "Fiscal tries again in a while.")
        }
    }
}
