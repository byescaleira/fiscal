import Foundation
import Observation

@MainActor @Observable
public final class UpdateHoldModel {
    public struct Connection {
        let start: @MainActor () async -> Void
        let stop: @MainActor () async -> Void

        public init(
            start: @escaping @MainActor () async -> Void,
            stop: @escaping @MainActor () async -> Void
        ) {
            self.start = start
            self.stop = stop
        }
    }

    public private(set) var isHolding = true
    @ObservationIgnored private let update: AppUpdateModel
    @ObservationIgnored private var connections: [Connection]?
    @ObservationIgnored private var isApplying = false

    public init(update: AppUpdateModel) {
        self.update = update
    }

    public func attach(_ connections: [Connection]) async {
        guard self.connections == nil else { return }
        self.connections = connections
        await apply()
    }

    public func apply() async {
        guard let connections, !isApplying else { return }
        isApplying = true
        defer { isApplying = false }
        while isHolding != update.isRequired {
            let holding = update.isRequired
            for connection in connections {
                if holding { await connection.stop() } else { await connection.start() }
            }
            isHolding = holding
        }
    }
}
