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
            ModelHost(SettingsLensModel(service: service)) {
                SettingsContent(destinations: destinations)
            }
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
    @Environment(SettingsModel.self) private var settings
    @Environment(SourcesModel.self) private var sources
    @Environment(\.featureFlags) private var flags
    let destinations: SettingsDestinations<Lens, Artists>?

    var body: some View {
        Group {
            #if os(macOS)
                Form { sections.surfaceRows() }.formStyle(.grouped).listSurface()
            #else
                AdaptiveList { sections }
            #endif
        }
        .emphasisTitle("Settings")
        .onAppear { settings.use(flags) }
        .task { await sources.load() }
    }

    @ViewBuilder private var sections: some View {
        if let destinations {
            SettingsYourFiscalSection(destinations: destinations)
        }
        SettingsGeneralSection()
        SettingsDataSection()
        if sources.isAvailable {
            SettingsSourcesSection()
        }
        SettingsHelpSection()
        DevelopmentRow()
    }
}

private struct SettingsYourFiscalSection<Lens: View, Artists: View>: View {
    @Environment(LensContext.self) private var lens: LensContext?
    @Environment(SessionModel.self) private var session: SessionModel?
    @Environment(SettingsLensModel.self) private var lensModel
    let destinations: SettingsDestinations<Lens, Artists>

    var body: some View {
        Section {
            if lens != nil {
                DisclosureLink {
                    destinations.lens
                } label: {
                    SettingsLensCard(summary: lensModel.summary(for: lens?.saved))
                }
            }
            SettingsRow(
                "Artists", detail: "The works behind the share cards, with their licenses",
                symbol: "paintpalette", color: .retroPlum
            ) {
                destinations.artists
            }
        } footer: {
            Text(
                "Who you support, your topics and your look stay on this device, outside iCloud and backups."
            )
        }
        .task { await lensModel.load(lens) }
        .task(id: lens?.saved?.supported) {
            await lensModel.loadFaces(
                for: lens?.saved?.supported ?? [], follows: session?.repositories.follows)
        }
    }
}

private struct SettingsGeneralSection: View {
    @Environment(SettingsModel.self) private var settings

    var body: some View {
        Section {
            SettingsRow(
                "Appearance", detail: "Theme, accent color and app icon", symbol: "paintbrush",
                color: RetroColor.tangerine.color, value: settings.appearance.title
            ) {
                AppearanceScreen()
            }
            #if os(iOS)
                SettingsRow(
                    "Notifications", symbol: "bell", color: RetroColor.cherry.color,
                    value: settings.highlightAlertsValue
                ) {
                    SettingsPage("Notifications") { HighlightAlertsSection() }
                }
            #endif
            SettingsRow("Privacy", symbol: "lock", color: RetroColor.plum.color) {
                SettingsPage("Privacy") { PrivacySection() }
            }
        } header: {
            Text("General").sectionTitle()
        }
    }
}

private struct HighlightAlertsSection: View {
    @Environment(SettingsModel.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Section {
            Toggle(isOn: $settings.highlightAlerts) {
                SettingsLabel(
                    "Highest-weight highlights on the Lock Screen",
                    detail:
                        "Only weight 85 or more, from the last day. Fiscal sends only an anonymous Apple token.",
                    symbol: "bell.badge", color: .retroRust)
            }
            .tint(.positive)
        }
    }
}

private struct PrivacySection: View {
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
                "Investigations in your iCloud",
                detail:
                    "Your investigations sync through your own iCloud account. Who you support never leaves this device.",
                symbol: "magnifyingglass", color: .retroPlum)
            SettingsLabel(
                "The Lens stays here",
                detail: "Who you support never goes to a server, a log or a share card.",
                symbol: "lock", color: .retroDenim)
        }
        if let url = settings.info.privacyURL {
            Section {
                Link(destination: url) {
                    SettingsExternalLabel(
                        "Privacy Policy", symbol: "doc.text", color: RetroColor.slate.color)
                }
            }
        }
    }
}

private struct SettingsDataSection: View {
    @Environment(SettingsModel.self) private var settings
    @Environment(OfflineDataModel.self) private var offline: OfflineDataModel?

    var body: some View {
        Section {
            SettingsRow(
                "iCloud", symbol: "icloud", color: RetroColor.sky.color,
                value: settings.cloudSyncValue
            ) {
                SettingsPage("iCloud") { CloudSection() }
            }
            if let offline {
                SettingsRow(
                    "Offline Data",
                    detail: "Today, your region and your people, ready without a connection",
                    symbol: "arrow.down.circle", color: .retroMustard,
                    value: offline.summary.isEmpty ? nil : offline.sizeText
                ) {
                    OfflineDataScreen().environment(offline)
                }
                .task { await offline.load() }
            }
        } header: {
            Text("Data").sectionTitle()
        }
    }
}

private struct CloudSection: View {
    @Environment(SettingsModel.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Section {
            Toggle(isOn: $settings.cloudSync) {
                SettingsLabel("Sync with iCloud", symbol: "icloud", color: RetroColor.sky.color)
            }
            .tint(.positive)
            .disabled(!settings.isCloudSyncAvailable)
        } footer: {
            Text(verbatim: settings.cloudFooter)
        }
    }
}

private struct SettingsSourcesSection: View {
    @Environment(SourcesModel.self) private var sources

    var body: some View {
        @Bindable var sources = sources
        Section {
            if let method = sources.method {
                Button {
                    sources.showMethod()
                } label: {
                    SettingsLabel(
                        "How We Measure", detail: "How weight puts what happens in order",
                        symbol: "scalemass", color: .retroMustard)
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $sources.isShowingMethod) {
                    WeightMethodSheet(method: method)
                }
            }
            SettingsRow(
                "Official Sources", detail: "Where every number comes from",
                symbol: "building.columns", color: .retroDenim, value: sources.countText
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

private struct SettingsHelpSection: View {
    @Environment(SettingsModel.self) private var settings
    @Environment(\.showGuide) private var showGuide

    var body: some View {
        Section {
            if showGuide != nil, settings.showsGuides {
                SettingsRow(
                    "Guides", detail: "Short guides for each part of the app", symbol: "book",
                    color: RetroColor.avocado.color
                ) {
                    GuidesHubScreen()
                }
            }
            SettingsRow(
                "About Fiscal", detail: "Who makes it, what's new, credits and contact",
                symbol: "info.circle", color: RetroColor.indigo.color, value: settings.info.version
            ) {
                AboutScreen()
            }
        } header: {
            Text("Help").sectionTitle()
        }
    }
}

private struct DevelopmentRow: View {
    @Environment(SettingsModel.self) private var settings

    var body: some View {
        #if DEBUG
            if settings.showsDeveloper {
                Section {
                    SettingsRow("Developer", symbol: "hammer", color: RetroColor.coffee.color) {
                        DeveloperScreen()
                    }
                }
            }
        #endif
    }
}
