import SwiftUI

extension EnvironmentValues {
    @Entry public var appTint: Color = .accentColor
}

extension View {
    public func appTint(_ color: Color) -> some View {
        tint(color).environment(\.appTint, color)
    }
}
