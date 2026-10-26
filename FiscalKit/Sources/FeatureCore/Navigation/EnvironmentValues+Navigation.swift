import SwiftUI

extension EnvironmentValues {
    @Entry public var open: FiscalDestination = .init { _, _ in }
    @Entry public var close: CloseAction = .init {}
    @Entry public var navigationSection: AppSection = .today
}
