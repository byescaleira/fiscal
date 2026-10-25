import SwiftUI

extension View {
    @ViewBuilder public func dismissKeyboardOnScroll() -> some View {
        #if os(visionOS) || os(tvOS)
            self
        #else
            scrollDismissesKeyboard(.immediately)
        #endif
    }
}
