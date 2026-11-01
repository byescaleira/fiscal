import AppIntents
import FiscalDomain
import SwiftUI
import WidgetKit

enum RepresentativesScope: String, AppEnum {
    case place
    case following

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Show")
    }

    static var caseDisplayRepresentations: [RepresentativesScope: DisplayRepresentation] {
        [.place: "My State", .following: "Who I Follow"]
    }
}

struct RepresentativesConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "My Representatives" }
    static var description: IntentDescription {
        IntentDescription("Choose whether the widget shows your state or who you follow.")
    }

    @Parameter(title: "Show", default: .place)
    var scope: RepresentativesScope

    init() {}
}

struct RepresentativesEntry: TimelineEntry {
    enum Content {
        case place(WidgetState<RepresentativesDigest>)
        case following(FollowingSnapshot)
    }

    let date: Date
    let content: Content
    var isSample = false

    var url: URL? {
        switch content {
        case .place: IntegrationLink.mine
        case .following: IntegrationLink.following
        }
    }

    static var sample: RepresentativesEntry {
        let offices: [Office] = [.governor, .senator, .senator, .senator]
        let place = PlaceRepresentatives(
            uf: "sp", name: HomePlace.name(of: "sp"),
            groups: [
                RepresentativeGroup(
                    level: .state, office: .governor, title: "", people: samplePeople(offices))
            ], sources: [])
        return RepresentativesEntry(
            date: .now, content: .place(.ready(RepresentativesDigest(place))), isSample: true)
    }

    static var followingSample: RepresentativesEntry {
        let offices: [Office] = [.senator, .federalDeputy, .federalDeputy, .senator]
        let entries = samplePeople(offices).map { FollowingSnapshot.Entry(person: $0, latest: nil) }
        return RepresentativesEntry(
            date: .now, content: .following(FollowingSnapshot(entries: entries, updatedAt: .now)),
            isSample: true)
    }

    private static func samplePeople(_ offices: [Office]) -> [PersonCard] {
        offices.enumerated().map { index, office in
            PersonCard(
                slug: "sample-\(index)", name: "Nome Sobrenome", office: office, uf: "sp",
                party: "", photo: nil, status: .inOffice)
        }
    }
}

struct RepresentativesProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> RepresentativesEntry {
        .sample
    }

    func snapshot(for configuration: RepresentativesConfiguration, in context: Context) async
        -> RepresentativesEntry
    {
        let entry = await Self.load(configuration.scope)
        guard context.isPreview else { return entry }
        switch entry.content {
        case .place(let state) where state.value == nil: return .sample
        case .following(let snapshot) where snapshot.entries.isEmpty: return .followingSample
        case .place, .following: return entry
        }
    }

    func timeline(for configuration: RepresentativesConfiguration, in context: Context) async
        -> Timeline<RepresentativesEntry>
    {
        let entry = await Self.load(configuration.scope)
        let next =
            switch entry.content {
            case .place(.unavailable): WidgetSchedule.retry(after: entry.date)
            case .place, .following: WidgetSchedule.nextRepresentativesRefresh(after: entry.date)
            }
        return Timeline(entries: [entry], policy: .after(next))
    }

    static func load(_ scope: RepresentativesScope) async -> RepresentativesEntry {
        switch scope {
        case .place: await loadPlace()
        case .following:
            RepresentativesEntry(date: .now, content: .following(FollowingSnapshot.read()))
        }
    }

    private static func loadPlace() async -> RepresentativesEntry {
        let uf = HomePlace().uf
        guard uf != nil else {
            return RepresentativesEntry(date: .now, content: .place(.needsPlace))
        }
        guard let feed = WidgetSource.feed() else {
            return RepresentativesEntry(date: .now, content: .place(.unavailable(offline: false)))
        }
        return RepresentativesEntry(date: .now, content: .place(await feed.representatives(uf: uf)))
    }
}

struct RepresentativesWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "fiscal.representatives", intent: RepresentativesConfiguration.self,
            provider: RepresentativesProvider()
        ) { entry in
            RepresentativesWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetStyle.board }
                .widgetURL(entry.url)
        }
        .configurationDisplayName("My Representatives")
        .description("Who represents your state, or who you follow, with a tap to each profile.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct RepresentativesWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RepresentativesEntry

    var body: some View {
        content
            .redacted(reason: entry.isSample ? .placeholder : [])
    }

    @ViewBuilder
    private var content: some View {
        switch entry.content {
        case .place(let state): place(state)
        case .following(let snapshot): following(snapshot)
        }
    }

    @ViewBuilder
    private func place(_ state: WidgetState<RepresentativesDigest>) -> some View {
        switch state {
        case .ready(let digest):
            if family == .systemSmall {
                RepresentativesSmall(digest: digest)
            } else {
                RepresentativesMedium(digest: digest)
            }
        case .needsPlace:
            WidgetMessage(
                symbol: "map", title: "Pick your state",
                detail: "Open Fiscal and choose your state in Following.")
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

    @ViewBuilder
    private func following(_ snapshot: FollowingSnapshot) -> some View {
        if snapshot.entries.isEmpty {
            WidgetMessage(
                symbol: "person.badge.plus", title: "Follow someone in Fiscal",
                detail: "Who you follow shows up here, with their latest update.")
        } else if family == .systemSmall {
            FollowingSmall(snapshot: snapshot)
        } else {
            FollowingMedium(snapshot: snapshot)
        }
    }
}
