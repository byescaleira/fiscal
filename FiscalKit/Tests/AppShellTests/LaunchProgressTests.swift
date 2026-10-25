import Testing

@testable import AppShell

@MainActor
struct LaunchProgressTests {
    @Test func completesWhenEveryStepFinishes() {
        let launch = LaunchProgress()
        #expect(launch.fraction == 0)
        launch.finish(.database)
        #expect(launch.fraction == 0.5)
        #expect(!launch.isComplete)
        launch.finish(.content)
        #expect(launch.isComplete)
        launch.dismiss()
        #expect(launch.isDismissed)
    }
}
