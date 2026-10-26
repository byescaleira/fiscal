import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import FiscalResource
import SwiftUI

public struct SettingsScreen<LensDestination: View, ArtistsDestination: View>: View {
    private let service: (any PublicDataService)?
    private let destinations: SettingsDestinations<LensDestination, ArtistsDestination>?

    public init(
        service: (any PublicDataService)?, @ViewBuilder lens: () -> LensDestination,
        @ViewBuilder artists: () -> ArtistsDestination
    ) {
        self.service = service
        destinations = SettingsDestinations(lens: lens(), artists: artists())
    }

    public var body: some View {
        ModelHost(SourcesModel(service: service)) {
            SettingsContent(destinations: destinations)
        }
    }
}

extension SettingsScreen where LensDestination == EmptyView, ArtistsDestination == EmptyView {
    public init() {
        service = nil
        destinations = nil
    }
}

struct SettingsDestinations<Lens: View, Artists: View> {
    let lens: Lens
    let artists: Artists
}

private struct SettingsContent<Lens: View, Artists: View>: View {
    @Environment(SourcesModel.self) private var sources
    let destinations: SettingsDestinations<Lens, Artists>?

    var body: some View {
        Group {
            #if os(macOS)
                Form { sections }.formStyle(.grouped)
            #else
                AdaptiveList { sections }
            #endif
        }
        .fontDesign(.rounded)
        .navigationTitle("Settings")
        .task { await sources.load() }
    }

    @ViewBuilder private var sections: some View {
        if let destinations {
            SettingsYourFiscalSection(destinations: destinations)
        }
        SettingsAppearanceSection()
        SettingsPrivacySection()
        if sources.isAvailable {
            SettingsSourcesSection()
        }
        SettingsAboutSection()
        DevelopmentRow()
    }
}

private struct SettingsYourFiscalSection<Lens: View, Artists: View>: View {
    @Environment(LensContext.self) private var lens: LensContext?
    @State private var catalog: ArtCatalog?
    let destinations: SettingsDestinations<Lens, Artists>

    var body: some View {
        Section {
            if lens != nil {
                DisclosureLink {
                    destinations.lens
                } label: {
                    SettingsLensCard(
                        summary: LensSummary(lens: lens?.saved, catalog: catalog))
                }
            }
            SettingsRow(
                "Artists", detail: "The works behind the share cards, with their licenses",
                symbol: "paintpalette", color: .retroPlum
            ) {
                destinations.artists
            }
        } footer: {
            Text("Your side, themes and look stay on this device, outside iCloud and backups.")
        }
        .task {
            await lens?.load()
            if catalog == nil { catalog = try? ArtCatalog.bundled() }
        }
    }
}

private struct SettingsAppearanceSection: View {
    @Environment(SettingsModel.self) private var settings

    var body: some View {
        Section {
            SettingsRow(
                "Appearance", detail: "Theme, accent color and app icon", symbol: "paintbrush",
                color: RetroColor.tangerine.color, value: settings.appearance.title
            ) {
                AppearanceScreen()
            }
        } header: {
            Text("Appearance").sectionTitle()
        }
    }
}

private struct SettingsPrivacySection: View {
    @Environment(SettingsModel.self) private var settings

    var body: some View {
        Section {
            SettingsLabel(
                "No account and no ads",
                detail: "Fiscal doesn't ask who you are and doesn't measure what you do.",
                symbol: "hand.raised", color: .retroOlive)
            SettingsLabel(
                "Your iCloud, your call",
                detail: "Who you follow syncs only through your own iCloud account.",
                symbol: "icloud", color: .retroTeal)
            SettingsLabel(
                "The Lens stays here",
                detail: "Your side never goes to a server, a log or a share card.",
                symbol: "lock", color: .retroDenim)
            if let url = settings.info.privacyURL {
                Link(destination: url) {
                    SettingsExternalLabel(
                        "Privacy Policy", symbol: "doc.text", color: RetroColor.slate.color)
                }
            }
        } header: {
            Text("Your Data and Privacy").sectionTitle()
        }
    }
}

private struct SettingsSourcesSection: View {
    @Environment(SourcesModel.self) private var sources
    @State private var isShowingMethod = false

    var body: some View {
        Section {
            if let method = sources.method {
                Button {
                    isShowingMethod = true
                } label: {
                    SettingsLabel(
                        "How We Measure", detail: "How weight puts what happens in order",
                        symbol: "scalemass", color: .retroMustard)
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $isShowingMethod) {
                    WeightMethodSheet(method: method)
                }
            }
            SettingsRow(
                "Official Sources", detail: "Where every number comes from",
                symbol: "building.columns", color: .retroDenim,
                value: sources.sources.isEmpty ? nil : PublicFormat.number(sources.sources.count)
            ) {
                SourcesScreen().environment(sources)
            }
        } header: {
            Text("Sources and Method").sectionTitle()
        } footer: {
            if let updated = sources.updatedText {
                Text(verbatim: updated)
            }
        }
    }
}

private struct SettingsAboutSection: View {
    @Environment(SettingsModel.self) private var settings
    @Environment(\.showGuide) private var showGuide
    @Environment(\.featureFlags) private var flags

    var body: some View {
        Section {
            if showGuide != nil, flags?.isOn(.guides) != false {
                SettingsRow(
                    "Guides", detail: "Short guides for each part of the app", symbol: "book",
                    color: RetroColor.avocado.color
                ) {
                    GuidesHubScreen()
                }
            }
            SettingsRow(
                "What's New", symbol: "sparkles", color: .companion, value: settings.info.number
            ) {
                WhatsNewScreen()
            }
            SettingsRow(
                "About Fiscal", detail: "Who makes it, credits and contact",
                symbol: "info.circle", color: RetroColor.indigo.color
            ) {
                AboutScreen()
            }
        } header: {
            Text("About").sectionTitle()
        }
    }
}

private struct DevelopmentRow: View {
    @Environment(\.featureFlags) private var flags

    var body: some View {
        #if DEBUG
            if flags != nil {
                Section {
                    SettingsRow("Developer", symbol: "hammer", color: RetroColor.coffee.color) {
                        SettingsPage("Developer") { FlagsSection() }
                    }
                }
            }
        #endif
    }
}
