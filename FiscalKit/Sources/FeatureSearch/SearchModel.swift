import FeatureCore
import FiscalDomain
import Foundation
import Observation

@MainActor @Observable
public final class SearchModel {
    public var query = ""
    public private(set) var hasLoaded = false

    public init() {}

    public var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public func load() async {
        hasLoaded = true
    }
}
