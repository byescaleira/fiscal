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
        AppShortcut(
            intent: FollowPersonIntent(),
            phrases: [
                "Follow \(\.$target) in \(.applicationName)",
                "Follow a politician in \(.applicationName)",
            ],
            shortTitle: "Follow", systemImageName: "person.badge.plus")
        AppShortcut(
            intent: UnfollowPersonIntent(),
            phrases: [
                "Unfollow \(\.$target) in \(.applicationName)",
                "Unfollow a politician in \(.applicationName)",
            ],
            shortTitle: "Unfollow", systemImageName: "person.badge.minus")
        AppShortcut(
            intent: OpenFollowingIntent(),
            phrases: [
                "Who I follow in \(.applicationName)",
                "Show who I follow in \(.applicationName)",
            ],
            shortTitle: "Following", systemImageName: "person.2")
    }
}

enum FiscalShortcutsSetup {
    @MainActor
    static func install() {
        IntegrationCenter.onPeopleIndexed = { FiscalShortcuts.updateAppShortcutParameters() }
    }
}
