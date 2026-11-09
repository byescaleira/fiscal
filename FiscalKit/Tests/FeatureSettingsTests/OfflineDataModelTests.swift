import FiscalDomain
import Foundation
import Testing

@testable import FeatureSettings

private actor FakeOfflinePack: OfflinePackService {
    private var stored: OfflinePackSummary
    private let next: OfflinePackSummary
    private let failure: PublicDataError?
    private(set) var erased = 0

    init(
        stored: OfflinePackSummary = .empty, next: OfflinePackSummary = .empty,
        failure: PublicDataError? = nil
    ) {
        self.stored = stored
        self.next = next
        self.failure = failure
    }

    func summary() async -> OfflinePackSummary { stored }

    func refresh() async throws -> OfflinePackSummary {
        if let failure { throw failure }
        stored = next
        return next
    }

    func erase() async -> OfflinePackSummary {
        erased += 1
        stored = .empty
        return .empty
    }
}

@MainActor
struct OfflineDataModelTests {
    private let saved = OfflinePackSummary(
        storedBytes: 3 * 1_024 * 1_024, originalBytes: 9 * 1_024 * 1_024, files: 120,
        people: 1_234, updatedAt: Date(timeIntervalSince1970: 1_800_000_000))

    @Test func loadsWhatIsOnTheDevice() async {
        let offline = OfflineDataModel(service: FakeOfflinePack(stored: saved))
        await offline.load()
        #expect(offline.summary == saved)
        #expect(offline.peopleText == PublicFormat.number(1_234))
        #expect(offline.filesText == PublicFormat.number(120))
        #expect(offline.fillFraction == 0.25)
        #expect(offline.updatedText != nil)
        #expect(offline.canErase)
    }

    @Test func refreshesAndClearsTheError() async {
        let offline = OfflineDataModel(service: FakeOfflinePack(next: saved))
        await offline.refresh()
        #expect(offline.summary == saved)
        #expect(offline.error == nil)
        #expect(!offline.isRefreshing)
    }

    @Test func keepsWhatItHasWhenTheRefreshFails() async {
        let offline = OfflineDataModel(service: FakeOfflinePack(stored: saved, failure: .offline))
        await offline.refresh()
        #expect(offline.error == .offline)
        #expect(offline.summary == saved)
    }

    @Test func confirmsBeforeErasing() async {
        let pack = FakeOfflinePack(stored: saved)
        let offline = OfflineDataModel(service: pack)
        await offline.load()
        offline.confirmErase()
        #expect(offline.isConfirmingErase)
        offline.cancelErase()
        #expect(!offline.isConfirmingErase)
        #expect(await pack.erased == 0)

        offline.confirmErase()
        await offline.erase()
        #expect(!offline.isConfirmingErase)
        #expect(!offline.isErasing)
        #expect(offline.summary.isEmpty)
        #expect(await pack.erased == 1)
    }

    @Test func hasNothingToEraseWhenEmpty() async {
        let offline = OfflineDataModel(service: FakeOfflinePack())
        await offline.load()
        #expect(!offline.canErase)
        offline.confirmErase()
        #expect(!offline.isConfirmingErase)
        #expect(offline.updatedText == nil)
        #expect(offline.fillFraction == 0)
    }
}
