import FeatureCore
import FiscalDomain
import Foundation
import Observation

@MainActor @Observable
public final class VoteDetailModel {
    public let id: String
    public private(set) var hasLoaded = false

    public init(id: String) {
        self.id = id
    }

    public var isEmpty: Bool { true }

    public func load() async {
        hasLoaded = true
    }
}
