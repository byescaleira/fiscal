import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct OfflineDataScreen: View {
    @Environment(OfflineDataModel.self) private var offline
    @State private var isConfirmingErase = false

    var body: some View {
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
                    value: PublicFormat.number(offline.summary.people))
                SettingsLabel(
                    "Files", symbol: "doc.on.doc", color: .retroOlive,
                    value: PublicFormat.number(offline.summary.files))
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
                    isConfirmingErase = true
                }
                .disabled(offline.isRefreshing || offline.summary.isEmpty)
                .confirmationDialog(
                    "Delete the offline data?", isPresented: $isConfirmingErase,
                    titleVisibility: .visible
                ) {
                    Button("Delete Offline Data", role: .destructive) {
                        Task { await offline.erase() }
                    }
                } message: {
                    Text("Fiscal downloads it again on the next update with a connection.")
                }
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
    }
}

private struct OfflineDataHeader: View {
    @Environment(OfflineDataModel.self) private var offline
    @Environment(\.appTint) private var appTint

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            Chip("On This Device", color: appTint, shape: .capsule)
                .textCase(.uppercase)
            Text(verbatim: offline.sizeText)
                .font(.scoreboardTitle)
                .monospacedDigit()
                .contentTransition(.numericText())
            Text("Up to \(offline.limitText)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ProgressBar(value: offline.fillFraction, color: appTint)
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
        .animation(.smooth, value: offline.summary)
        .accessibilityElement(children: .combine)
    }
}
