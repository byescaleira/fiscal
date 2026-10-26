import AppIntents
import AppShell

nonisolated struct FiscalAppIntents: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] { [FiscalIntentsPackage.self] }
}

nonisolated struct FiscalShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RepresentativesVoteIntent(),
            phrases: [
                "How did my deputy vote in \(.applicationName)",
                "How did my representatives vote in \(.applicationName)",
                "Latest vote in \(.applicationName)",
            ],
            shortTitle: "How They Voted", systemImageName: "checkmark.square")
        AppShortcut(
            intent: OpenPersonIntent(),
            phrases: [
                "Open the profile of \(\.$target) in \(.applicationName)",
                "Open a profile in \(.applicationName)",
            ],
            shortTitle: "Open Profile", systemImageName: "person.crop.circle")
        AppShortcut(
            intent: ShowRacesIntent(),
            phrases: [
                "Show the vote count in \(.applicationName)",
                "Election results in \(.applicationName)",
            ],
            shortTitle: "Vote Count", systemImageName: "chart.bar.xaxis")
    }
}

enum FiscalShortcutsSetup {
    @MainActor
    static func install() {
        IntegrationCenter.onPeopleIndexed = { FiscalShortcuts.updateAppShortcutParameters() }
    }
}
