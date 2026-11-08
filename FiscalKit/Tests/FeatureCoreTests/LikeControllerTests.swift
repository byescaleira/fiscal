import FiscalDomain
import Foundation
import Testing

@testable import FeatureCore

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct LikeControllerTests {
    private actor Store: LikeRepository {
        var items: [LikedItem] = []
        var fails = false

        func liked() async throws -> [LikedItem] { items.sorted { $0.likedAt > $1.likedAt } }
        func like(_ item: LikedItem) async throws {
            if fails { throw FiscalError.onSave }
            items.removeAll { $0.id == item.id }
            items.append(item)
        }
        func unlike(id: String) async throws {
            if fails { throw FiscalError.onSave }
            items.removeAll { $0.id == id }
        }
        func reset() async throws {
            if fails { throw FiscalError.onSave }
            items = []
        }
        func failNext() { fails = true }
    }

    private actor SlowStore: LikeRepository {
        var items: [LikedItem] = []
        var calls = 0
        private var gate: CheckedContinuation<Void, Never>?

        func liked() async throws -> [LikedItem] { items }
        func like(_ item: LikedItem) async throws {
            calls += 1
            await withCheckedContinuation { gate = $0 }
            items.append(item)
        }
        func unlike(id: String) async throws { items.removeAll { $0.id == id } }
        func reset() async throws { items = [] }
        func isWaiting() -> Bool { gate != nil }
        func open() {
            gate?.resume()
            gate = nil
        }
    }

    nonisolated private static func item(_ id: String, at seconds: TimeInterval = 1) -> LikedItem {
        LikedItem(
            id: "event-\(id)", kind: .event, title: id,
            day: CalendarDay(Date(timeIntervalSince1970: 0)),
            likedAt: Date(timeIntervalSince1970: seconds))
    }

    @Test func likesAndUnlikes() async {
        let store = Store()
        let like = LikeController(likes: store)
        #expect(await like.toggle(Self.item("a")))
        #expect(like.isLiked("event-a"))
        #expect(await store.items.map(\.id) == ["event-a"])
        #expect(await !like.toggle(Self.item("a")))
        #expect(!like.isLiked("event-a"))
        #expect(await store.items.isEmpty)
    }

    @Test func theNewestLikeComesFirst() async {
        let like = LikeController(likes: Store())
        await like.toggle(Self.item("a", at: 1))
        await like.toggle(Self.item("b", at: 2))
        #expect(like.items.map(\.id) == ["event-b", "event-a"])
        #expect(like.liked == ["event-a", "event-b"])
    }

    @Test func reloadsWhatTheStoreHas() async throws {
        let store = Store()
        try await store.like(Self.item("x"))
        let like = LikeController(likes: store)
        await like.reload()
        #expect(like.liked == ["event-x"])
        #expect(like.hasLoaded)
    }

    @Test func aFailedSaveGoesBackAndReportsTheError() async {
        let store = Store()
        await store.failNext()
        let like = LikeController(likes: store)
        #expect(await !like.toggle(Self.item("a")))
        #expect(!like.isLiked("event-a"))
        #expect(like.error == .onSave)
    }

    @Test func aFailedUnlikeKeepsTheItem() async throws {
        let store = Store()
        let like = LikeController(likes: store)
        await like.toggle(Self.item("a"))
        await store.failNext()
        #expect(await like.toggle(Self.item("a")))
        #expect(like.isLiked("event-a"))
        await like.remove(id: "event-a")
        #expect(like.isLiked("event-a"))
        #expect(like.error == .onRemove)
    }

    @Test func ignoresASecondTapWhileTheFirstIsSaving() async {
        let store = SlowStore()
        let like = LikeController(likes: store)
        let first = Task { await like.toggle(Self.item("a")) }
        while await !store.isWaiting() { await Task.yield() }
        #expect(await like.toggle(Self.item("a")))
        await store.open()
        #expect(await first.value)
        #expect(await store.calls == 1)
        #expect(like.isLiked("event-a"))
    }

    @Test func removingAndErasing() async {
        let store = Store()
        let like = LikeController(likes: store)
        await like.toggle(Self.item("a", at: 1))
        await like.toggle(Self.item("b", at: 2))
        await like.remove(id: "event-a")
        #expect(like.items.map(\.id) == ["event-b"])
        await like.erase()
        #expect(like.items.isEmpty)
        #expect(await store.items.isEmpty)
    }

    @Test func anItemStillInTheFeedOpensWhatTheFeedShows() throws {
        let like = LikeController(likes: Store())
        let detail = try #require(URL(string: "https://www.camara.leg.br/1"))
        let proposal = LikedItem(
            id: "action-1", kind: .proposal, title: "PLP", day: CalendarDay(.now), likedAt: .now)
        #expect(like.destination(for: proposal) == nil)
        like.showing(["action-1": .settings])
        #expect(like.destination(for: proposal) == .settings)
        let vote = LikedItem(
            id: "vote-1", kind: .vote, title: "PEC", day: CalendarDay(.now), likedAt: .now,
            voteID: "1", url: detail)
        #expect(like.destination(for: vote) == .vote(id: "1"))
        like.showing([:])
        #expect(like.destination(for: proposal) == nil)
    }

    @Test func withoutAStoreNothingChanges() async {
        let like = LikeController(likes: nil)
        #expect(await !like.toggle(Self.item("a")))
        #expect(like.items.isEmpty)
    }
}
