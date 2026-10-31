import Observation

@MainActor @Observable
public final class HoldGate {
    public private(set) var isHeld = true

    public init() {}

    public func hold() {
        isHeld = true
    }

    public func release() {
        isHeld = false
    }

    public var connection: UpdateHoldModel.Connection {
        UpdateHoldModel.Connection {
            self.release()
        } stop: {
            self.hold()
        }
    }
}
