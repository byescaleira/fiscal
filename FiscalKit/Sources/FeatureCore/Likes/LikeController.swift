import FiscalDomain
import Foundation
import Observation

@MainActor @Observable
public final class LikeController {
    public private(set) var items: [LikedItem] = []
    public private(set) var hasLoaded = false
    public var error: FiscalError?
    @ObservationIgnored private let likes: (any LikeRepository)?
    @ObservationIgnored private var pending: Set<String> = []

    public init(likes: (any LikeRepository)?) {
        self.likes = likes
    }

    public var liked: Set<String> { Set(items.map(\.id)) }

    public func isLiked(_ id: String) -> Bool {
        items.contains { $0.id == id }
    }

    public func reload() async {
        guard let likes else { return }
        do {
            items = try await likes.liked()
            hasLoaded = true
        } catch is CancellationError {} catch {
            self.error = .onFetch
        }
    }

    @discardableResult
    public func toggle(_ item: LikedItem) async -> Bool {
        guard let likes, pending.insert(item.id).inserted else { return isLiked(item.id) }
        defer { pending.remove(item.id) }
        let before = items
        do {
            if isLiked(item.id) {
                items.removeAll { $0.id == item.id }
                try await likes.unlike(id: item.id)
            } else {
                items.insert(item, at: 0)
                try await likes.like(item)
            }
        } catch {
            items = before
            self.error = .onSave
        }
        return isLiked(item.id)
    }

    public func remove(id: String) async {
        guard let likes, isLiked(id), pending.insert(id).inserted else { return }
        defer { pending.remove(id) }
        let before = items
        items.removeAll { $0.id == id }
        do {
            try await likes.unlike(id: id)
        } catch {
            items = before
            self.error = .onRemove
        }
    }

    public func erase() async {
        guard let likes else { return }
        let before = items
        items = []
        do {
            try await likes.reset()
        } catch {
            items = before
            self.error = .onRemove
        }
    }
}
