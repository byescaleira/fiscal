import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public struct SettingsScreen<Extra: View>: View {
    private let extra: Extra

    public init(@ViewBuilder extra: () -> Extra) {
        self.extra = extra()
    }

    public var body: some View {
        Group {
            #if os(macOS)
                Form { SettingsSections(extra: extra) }.formStyle(.grouped)
            #else
                AdaptiveList { SettingsSections(extra: extra) }
            #endif
        }
        .navigationTitle("Settings")
    }
}

extension SettingsScreen where Extra == EmptyView {
    public init() {
        self.init { EmptyView() }
    }
}

private struct SettingsSections<Extra: View>: View {
    @Environment(SettingsModel.self) private var settings
    @Environment(\.showGuide) private var showGuide
    @Environment(\.featureFlags) private var flags
    let extra: Extra

    var body: some View {
        Section {
            SettingsRow(
                "Appearance", symbol: "paintbrush", color: RetroColor.tangerine.color,
                value: settings.appearance.title
            ) {
                AppearanceScreen()
            }
        } header: {
            Text("General")
        }
        extra
        Section {
            if showGuide != nil, flags?.isOn(.guides) != false {
                SettingsRow("Guides", symbol: "book", color: RetroColor.avocado.color) {
                    GuidesHubScreen()
                }
            }
            SettingsRow(
                "About Fiscal", symbol: "info.circle", color: RetroColor.indigo.color,
                value: settings.info.version
            ) {
                AboutScreen()
            }
        } header: {
            Text("Help")
        }
        DevelopmentRow()
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
