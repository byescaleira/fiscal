import FiscalDomain
import Foundation
import Testing

@testable import FeatureCore

@MainActor
private final class Pages {
    var shown: [String] = []
    var phase = PublicDataPhase.idle
    let requests = PublicDataRequests()
    var gates: [String: CheckedContinuation<Void, Never>] = [:]

    func load(_ page: String) async {
        phase = .loading
        phase = await PublicDataPhase.settle(after: phase, in: requests) {
            await withCheckedContinuation { self.gates[page] = $0 }
            return page
        } apply: { value in
            self.shown.append(value)
        }
    }

    func answer(_ page: String) {
        gates.removeValue(forKey: page)?.resume()
    }

    func waitForRequest(_ page: String) async {
        let deadline = ContinuousClock.now + .seconds(5)
        while gates[page] == nil, ContinuousClock.now < deadline { await Task.yield() }
    }
}

@MainActor
struct PublicDataPhaseTests {
    @Test func aLateAnswerToAnOlderRequestIsIgnored() async {
        let pages = Pages()
        let older = Task { await pages.load("2025") }
        await pages.waitForRequest("2025")
        let newer = Task { await pages.load("2026") }
        await pages.waitForRequest("2026")
        pages.answer("2026")
        await newer.value
        #expect(pages.shown == ["2026"])
        #expect(pages.phase == .loaded)
        pages.answer("2025")
        await older.value
        #expect(pages.shown == ["2026"])
        #expect(pages.phase == .loaded)
    }

    @Test func anOlderAnswerBeforeTheNewerKeepsLoading() async {
        let pages = Pages()
        let older = Task { await pages.load("2025") }
        await pages.waitForRequest("2025")
        let newer = Task { await pages.load("2026") }
        await pages.waitForRequest("2026")
        pages.answer("2025")
        await older.value
        #expect(pages.shown.isEmpty)
        #expect(pages.phase == .loading)
        pages.answer("2026")
        await newer.value
        #expect(pages.shown == ["2026"])
        #expect(pages.phase == .loaded)
    }

    @Test func aCancelledLoadNeverReportsLoaded() async {
        let requests = PublicDataRequests()
        let task = Task { @MainActor in
            await PublicDataPhase.settle(after: .loading, in: requests) {
                withUnsafeCurrentTask { $0?.cancel() }
            } apply: { _ in
                Issue.record("A cancelled load applied its value")
            }
        }
        #expect(await task.value == .idle)
    }

    @Test func aFailureKeepsTheError() async {
        let phase = await PublicDataPhase.settle(after: .loading, in: PublicDataRequests()) {
            throw PublicDataError.offline
        } apply: { (_: Void) in
            Issue.record("A failed load applied its value")
        }
        #expect(phase == .failed(.offline))
    }
}
