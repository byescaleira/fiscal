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
        prominentButton()
            .controlSize(.large)
            .buttonSizing(.flexible)
            .font(.headline.weight(.bold))
            .fontDesign(.rounded)
    }
}
