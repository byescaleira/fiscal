import SwiftUI

extension View {
    @ViewBuilder func routeInspector<Content: View>(
        isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        #if os(visionOS)
            modifier(RouteWindowOpener())
        #else
            inspector(isPresented: isPresented, content: content)
        #endif
    }
}
