import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct DeveloperScreen: View {
    @Environment(\.featureFlags) private var flags
    @Environment(AppUpdateModel.self) private var update: AppUpdateModel?
    @Environment(SessionModel.self) private var session: SessionModel?

    var body: some View {
        ModelHost(DeveloperModel(flags: flags, update: update, session: session)) {
            DeveloperPage()
        }
    }
}

private struct DeveloperPage: View {
    @Environment(DeveloperModel.self) private var developer

    var body: some View {
        @Bindable var developer = developer
        SettingsPage("Developer") {
            if developer.hasFlags { DeveloperFlagsSection() }
            if developer.canSimulateUpdates { DeveloperUpdatesSection() }
            DeveloperDataSection()
            DeveloperPreferencesSection()
            DeveloperAppSection()
        }
        .confirmationDialog(
            "Delete the preferences?", isPresented: $developer.isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete Preferences", role: .destructive) { developer.deletePreferences() }
        } message: {
            Text(verbatim: developer.preferencesFooter)
        }
        .onAppear { developer.countPreferences() }
    }
}

private struct DeveloperFlagsSection: View {
    @Environment(DeveloperModel.self) private var developer

    var body: some View {
        Section {
            ForEach(FeatureFlag.allCases) { flag in
                Toggle(
                    flag.title,
                    isOn: Binding(
                        get: { developer.isOn(flag) }, set: { developer.set(flag, isOn: $0) }))
            }
            .tint(.positive)
            Button {
                developer.restoreFlags()
            } label: {
                IconRow("Restore Defaults", symbol: "arrow.uturn.backward", color: .companion)
            }
            .disabled(!developer.hasOverrides)
        } header: {
            Text("Flags").sectionTitle()
        } footer: {
            Text(
                "This device's rollout group: \(developer.bucket). Only shown in development builds."
            )
        }
    }
}

private struct DeveloperUpdatesSection: View {
    @Environment(DeveloperModel.self) private var developer
    @Environment(\.appTint) private var appTint

    var body: some View {
        @Bindable var developer = developer
        Section {
            Picker("Simulation", selection: $developer.simulation) {
                ForEach(DeveloperModel.simulations, id: \.self) { state in
                    Text(verbatim: DeveloperModel.title(of: state)).tag(state)
                }
            }
            LabeledContent("Installed", value: developer.installedText)
            LabeledContent("Remote State", value: developer.remoteStateText)
            LabeledContent("Remote Policy", value: developer.policyText)
            LabeledContent("Last Check", value: developer.lastCheckText)
            Button {
                Task { await developer.checkNow() }
            } label: {
                HStack(spacing: .spaceS) {
                    IconRow("Check Now", symbol: "arrow.clockwise", color: appTint)
                    if developer.isChecking { ProgressView() }
                }
            }
            .disabled(developer.isChecking)
        } header: {
            Text("App Updates").sectionTitle()
        } footer: {
            Text(
                "The simulation stays in the shared cache, so shortcuts and widgets see it too. Debug builds never block for real."
            )
        }
    }
}

private struct DeveloperDataSection: View {
    @Environment(DeveloperModel.self) private var developer
    @Environment(\.appTint) private var appTint

    var body: some View {
        Section {
            Button {
                Task { await developer.reloadData() }
            } label: {
                HStack(spacing: .spaceS) {
                    IconRow("Reload Data", symbol: "arrow.triangle.2.circlepath", color: appTint)
                    if developer.isReloading { ProgressView() }
                }
            }
            .disabled(!developer.canReload || developer.isReloading)
        } header: {
            Text("Data").sectionTitle()
        } footer: {
            Text("Reloads every screen from the database and reads the remote flags again.")
        }
    }
}

private struct DeveloperPreferencesSection: View {
    @Environment(DeveloperModel.self) private var developer

    var body: some View {
        Section {
            Button {
                developer.confirmDeletePreferences()
            } label: {
                IconRow(
                    "Delete Preferences", symbol: "trash", color: .negative,
                    titleColor: .negative)
            }
            .disabled(developer.preferenceCount == .zero)
        } header: {
            Text("Preferences").sectionTitle()
        } footer: {
            Text(verbatim: developer.preferencesFooter)
        }
    }
}

private struct DeveloperAppSection: View {
    @Environment(DeveloperModel.self) private var developer

    var body: some View {
        Section {
            LabeledContent("Version", value: developer.versionText)
            LabeledContent("Build", value: developer.buildText)
            LabeledContent("Identifier", value: developer.identifierText)
        } header: {
            Text("App").sectionTitle()
        }
    }
}
