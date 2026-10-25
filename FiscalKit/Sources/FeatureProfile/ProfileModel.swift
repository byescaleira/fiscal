import FeatureCore
import FiscalDomain
import Foundation
import Observation

@MainActor @Observable
public final class ProfileModel {
    public let slug: String
    public private(set) var hasLoaded = false

    public init(slug: String) {
        self.slug = slug
    }

    public var isEmpty: Bool { true }

    public func load() async {
        hasLoaded = true
    }
}
