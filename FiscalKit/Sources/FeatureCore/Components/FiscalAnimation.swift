import ByescaleiraAnimation
import FiscalDesignSystem
import FiscalResource
import SwiftUI

public enum FiscalAnimation: String, CaseIterable, Sendable {
    case backup
    case done
    case editor
    case launch
    case privacy
    case widgets
}

public struct FiscalAnimationView: View {
    private let animation: FiscalAnimation
    private let loops: Bool
    private let isStill: Bool

    public init(_ animation: FiscalAnimation, loops: Bool = false, isStill: Bool = false) {
        self.animation = animation
        self.loops = loops
        self.isStill = isStill
    }

    public var body: some View {
        PaletteAnimationView(animation.rawValue, loops: loops, isStill: isStill) {
            FiscalResourceAnimation.json(named: animation.rawValue)
        }
    }
}
