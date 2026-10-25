import FiscalDomain
import Testing

@testable import FeatureCore

@MainActor
struct EditorStatusTests {
    @Test func loadsOnceAndSaves() async {
        let status = EditorStatus()
        var loads = 0
        await status.load { loads += 1 }
        await status.load { loads += 1 }
        #expect(loads == 1)
        #expect(status.isLoaded)
        await status.save {}
        #expect(status.isSaved)
        #expect(status.isLocked)
    }

    @Test func keepsDomainErrorsAndFallsBackOtherwise() async {
        let status = EditorStatus()
        await status.load { throw FiscalError.missingRecord }
        #expect(status.error == .missingRecord)
        #expect(!status.isLoaded)
        let other = EditorStatus()
        await other.load {}
        await other.remove { throw CancellationError() }
        #expect(other.error == .onRemove)
        #expect(!other.isSaved)
    }
}
