import FeatureCore
import FiscalDomain
import Foundation
import Observation

@MainActor @Observable
public final class CompareModel {
    public let slugs: [String]

    public init(slugs: [String]) {
        self.slugs = slugs
    }

    public var isEmpty: Bool { slugs.count < 2 }
}
