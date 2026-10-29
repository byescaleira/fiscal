import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct OfflineDataScreen: View {
    @Environment(OfflineDataModel.self) private var offline

    var body: some View {
        @Bindable var offline = offline
        SettingsPage("Offline Data") {
            Section {
                OfflineDataHeader()
            } footer: {
                Text(
                    "Today's summary, the latest votes, the vote count, your region and the full profiles of who you follow, support and represents you."
                )
            }
            Section {
                SettingsLabel(
                    "People saved", symbol: "person.2", color: .retroDenim,
                    value: offline.peopleText)
                SettingsLabel(
                    "Files", symbol: "doc.on.doc", color: .retroOlive, value: offline.filesText)
                SettingsLabel(
                    "Without compression", symbol: "arrow.up.left.and.arrow.down.right",
                    color: .retroMustard, value: offline.originalText)
            }
            Section {
                Button {
                    Task { await offline.refresh() }
                } label: {
                    HStack(spacing: .spaceS) {
                        Label("Update Now", systemImage: "arrow.clockwise")
                        Spacer(minLength: .zero)
                        if offline.isRefreshing { ProgressView() }
                    }
                }
                .disabled(offline.isRefreshing)
                Button("Delete Offline Data", systemImage: "trash", role: .destructive) {
                    offline.confirmErase()
                }
                .disabled(!offline.canErase)
            } footer: {
                if let error = offline.error {
                    Text(verbatim: error.message)
                } else {
                    Text(
                        "It updates by itself when there's a connection, only for what changed. It stays on this device, outside iCloud and backups. The profiles of who you support download like any other profile: the server never learns it's support."
                    )
                }
            }
        }
        .task { await offline.load() }
        .sheet(isPresented: $offline.isConfirmingErase) {
            OfflineEraseGuide().environment(offline)
        }
    }
}

private struct OfflineEraseGuide: View {
    @Environment(OfflineDataModel.self) private var offline

    var body: some View {
        GuideSheet(
            index: 0, count: 1, isWorking: offline.isErasing,
            primary: GuideAction("Delete Offline Data") { Task { await offline.erase() } },
            secondary: GuideAction("Keep Offline Data") { offline.cancelErase() }
        ) {
            GuidePage(
                title: "Delete the offline data?",
                message: "Fiscal downloads it again on the next update with a connection."
            ) {
                FiscalAnimationView(.backup)
            }
        }
    }
}

private struct OfflineDataHeader: View {
    @Environment(OfflineDataModel.self) private var offline
    @Environment(\.appTint) private var appTint
    @Environment(\.settingsReducesMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            Chip("On This Device", color: appTint, shape: .capsule)
                .textCase(.uppercase)
            Text(verbatim: offline.sizeText)
                .font(.scoreboardTitle)
                .monospacedDigit()
                .contentTransition(reduceMotion ? .opacity : .numericText())
            Text("Up to \(offline.limitText)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            OfflineFillBar(value: offline.fillFraction, color: appTint)
            Group {
                if let updated = offline.updatedText {
                    Text("Updated \(updated)")
                } else {
                    Text("Not downloaded yet")
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, .spaceXS)
        .animation(reduceMotion ? nil : .smooth, value: offline.summary)
        .accessibilityElement(children: .combine)
    }
}

private struct OfflineFillBar: View {
    @Environment(\.settingsReducesMotion) private var reduceMotion
    @State private var isFilled = false
    let value: Double
    let color: Color

    var body: some View {
        ProgressBar(value: isFilled || reduceMotion ? value : .zero, color: color)
            .animation(reduceMotion ? nil : .smooth, value: isFilled)
            .task { isFilled = true }
    }
}
