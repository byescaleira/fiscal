import Foundation
import SwiftUI

extension EnvironmentValues {
    @Entry public var shareProgress: Double = 1
    @Entry public var shareShowsArt = true
}

public enum ShareMotion {
    public static func eased(_ progress: Double) -> Double {
        let clamped = min(max(progress, 0), 1)
        return 1 - pow(1 - clamped, 3)
    }

    public static func fill(_ share: Double, progress: Double) -> Double {
        min(max(share, 0), 1) * eased(progress)
    }
}
