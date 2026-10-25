import AppShell
import FeatureCore
import FeatureSettings
import FiscalData
import Observation
import SwiftUI

@main
struct FiscalApp: App {
    @State private var settings: SettingsModel
    @State private var bootstrap: FiscalBootstrap

    init() {
        #if DEBUG && !targetEnvironment(simulator)
            if CommandLine.arguments.contains("-FiscalInitializeCloudSchema") {
                FiscalDatabase.initializeCloudSchema()
            }
        #endif
        let settings = SettingsModel()
        _settings = State(initialValue: settings)
        _bootstrap = State(initialValue: FiscalBootstrap())
    }

    var body: some Scene {
        WindowGroup {
            FiscalRootView()
                .environment(bootstrap)
                .environment(bootstrap.update)
                .featureFlags(bootstrap.flags)
                .fiscalSettings(settings)
        }
        #if os(macOS)
            Settings {
                FiscalSettingsWindow()
                    .environment(bootstrap.update)
                    .environment(bootstrap.export)
                    .featureFlags(bootstrap.flags)
                    .fiscalSettings(settings)
            }
        #endif
    }
}

@MainActor @Observable
private final class FiscalBootstrap {
    private(set) var database: FiscalDatabase?
    private(set) var export: DataExportModel?
    private(set) var error: String?
    let flags: FeatureFlags
    let update: AppUpdateModel
    let hold: UpdateHoldModel

    init() {
        #if targetEnvironment(simulator)
            flags = FeatureFlags()
            update = AppUpdateModel()
        #else
            flags = FeatureFlags(source: CloudKitFlagSource())
            update = AppUpdateModel(source: CloudKitAppReleaseSource())
        #endif
        hold = UpdateHoldModel(update: update)
    }

    func prepare() async {
        guard database == nil else { return }
        error = nil
        if update.isRequired {
            await update.refresh(force: true)
        } else {
            Task { await update.refresh() }
        }
        do {
            let database = try await FiscalServices.shared.database(
                cloudSync: FiscalServices.launchCloudSync && !update.isRequired)
            self.database = database
            export = DataExportModel(repositories: database.repositories)
            Task { await flags.refresh() }
            await hold.attach([])
        } catch {
            self.error = error.localizedDescription
        }
    }
}

#if os(macOS)
    private struct FiscalSettingsWindow: View {
        @Environment(AppUpdateModel.self) private var update

        var body: some View {
            if update.isRequired {
                UpdateRequiredScreen()
            } else {
                NavigationStack { SettingsScreen() }
            }
        }
    }
#endif

private struct FiscalRootView: View {
    @Environment(FiscalBootstrap.self) private var bootstrap
    @Environment(AppUpdateModel.self) private var update
    @Environment(\.scenePhase) private var scenePhase
    @State private var window: FiscalWindow?
    @State private var launch = LaunchProgress()
    @State private var attempt = 0

    var body: some View {
        Group {
            if update.isRequired {
                UpdateRequiredScreen()
                    .environment(bootstrap.export)
                    .transition(.opacity)
            } else if let window {
                MainScreen().fiscalWindow(window).environment(launch)
            } else if let error = bootstrap.error {
                ContentUnavailableView {
                    Label(
                        "Couldn't open Fiscal",
                        systemImage: "externaldrive.badge.exclamationmark")
                } description: {
                    Text(error)
                } actions: {
                    Button("Try Again") { attempt += 1 }
                }
            } else {
                SplashScreen(progress: launch.fraction, status: launch.status)
            }
        }
        .animation(.easeOut(duration: 0.2), value: update.isRequired)
        .onChange(of: update.isRequired) {
            Task { await bootstrap.hold.apply() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await update.refresh() } }
        }
        .task(id: attempt) {
            guard window == nil else { return }
            await bootstrap.prepare()
            guard !Task.isCancelled else { return }
            if let database = bootstrap.database {
                window = FiscalWindow(provider: database)
                launch.finish(.database)
            }
        }
    }
}
