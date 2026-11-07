import ByescaleiraAccessibility
import ByescaleiraDesign
import SwiftUI

@propertyWrapper
public struct ReducesMotion: DynamicProperty {
    @Environment(\.accessibilityReduceMotion) private var system
    @Environment(\.liteMode) private var liteMode

    public init() {}

    public var wrappedValue: Bool { system || liteMode.reducesMotion }
}

extension View {
    public func quietBounce<Value: Equatable>(value: Value) -> some View {
        modifier(QuietBounce(value: value))
    }
}

private struct QuietBounce<Value: Equatable>: ViewModifier {
    @ReducesMotion private var reduceMotion
    let value: Value

    func body(content: Content) -> some View {
        content
            .symbolEffect(.bounce, value: value)
            .symbolEffectsRemoved(reduceMotion || MotionBudget.isConstrained)
    }
}
