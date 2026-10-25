import SwiftUI

public struct FiscalDestination: Sendable {
    private let action: @MainActor @Sendable (Route, AppSection) -> Void
    public init(_ action: @escaping @MainActor @Sendable (Route, AppSection) -> Void) {
        self.action = action
    }
    @MainActor public func callAsFunction(_ route: Route, in section: AppSection) {
        action(route, section)
    }
}
