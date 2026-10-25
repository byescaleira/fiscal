import FeatureCore
import FiscalDomain
import Foundation
import Observation

@MainActor @Observable
public final class LensModel {
    public private(set) var hasLoaded = false

    public init() {}

    public var isEmpty: Bool { true }

    public func load() async {
        hasLoaded = true
    }
}
