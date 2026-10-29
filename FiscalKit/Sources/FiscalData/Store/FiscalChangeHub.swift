import CoreData
import FiscalDomain
import Foundation

public final class FiscalChangeHub: @unchecked Sendable, StorageChangeFeed {
    private let lock = NSLock()
    private var revision: UInt64 = 0
    private var listeners: [UUID: AsyncStream<StorageChange>.Continuation] = [:]
    private var observer: (any NSObjectProtocol)?
    private let center: NotificationCenter

    public init(center: NotificationCenter = .default) {
        self.center = center
        observer = center.addObserver(
            forName: .NSPersistentStoreRemoteChange, object: nil, queue: nil
        ) { [weak self] _ in
            self?.publish(.remote)
        }
    }

    deinit {
        if let observer { center.removeObserver(observer) }
    }

    public var remoteRevision: UInt64 { lock.withLock { revision } }

    public func changes() -> AsyncStream<StorageChange> {
        let id = UUID()
        return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            lock.withLock { listeners[id] = continuation }
            continuation.onTermination = { [weak self] _ in self?.remove(id) }
        }
    }

    public func publish(_ change: StorageChange) {
        let current = lock.withLock {
            if change.isRemote { revision &+= 1 }
            return Array(listeners.values)
        }
        for listener in current { listener.yield(change) }
    }

    private func remove(_ id: UUID) {
        _ = lock.withLock { listeners.removeValue(forKey: id) }
    }
}
