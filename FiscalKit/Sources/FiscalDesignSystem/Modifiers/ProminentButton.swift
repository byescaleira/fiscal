import SwiftUI

extension View {
    @ViewBuilder public func prominentButton() -> some View {
        #if os(visionOS)
            buttonStyle(.borderedProminent)
        #else
            buttonStyle(.glassProminent)
        #endif
    }

    public func primaryButton() -> some View {
        modifier(PrimaryButtonLabel())
            .prominentButton()
            .controlSize(.large)
            .buttonSizing(.flexible)
            .font(.emphasis(.headline, weight: .bold))
    }
}

private struct PrimaryButtonLabel: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.foregroundStyle(colorScheme == .dark ? Color.black : Color.white)
    }
}
