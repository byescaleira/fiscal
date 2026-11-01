import FiscalDesignSystem
import SwiftUI

public enum ReadingLayout: Equatable, Sendable {
    case stack
    case beside
    case folded(Axis)

    public init(_ context: LayoutContext) {
        if context.isAccessibilitySize {
            self = .stack
        } else if case .folded(let axis, _) = context.posture {
            self = .folded(axis)
        } else {
            self = context.opensRoutesBeside ? .beside : .stack
        }
    }

    public var isFolded: Bool {
        if case .folded = self { true } else { false }
    }

    public var routeComesFirst: Bool {
        self == .folded(.vertical)
    }
}
