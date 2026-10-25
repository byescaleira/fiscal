import SwiftUI

extension View {
    public func loading(_ isLoading: Bool) -> some View {
        redacted(reason: isLoading ? .placeholder : [])
    }
}

extension EnvironmentValues {
    @Entry public var isLoading: Bool = false
}
