import SwiftUI

extension View {
    public func sectionTitle() -> some View {
        font(.emphasis(.title3, weight: .semibold)).foregroundStyle(Color.primary)
    }
}
