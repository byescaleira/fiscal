import SwiftUI

extension View {
    public func sectionTitle() -> some View {
        font(.title3.weight(.semibold)).fontDesign(.rounded).foregroundStyle(Color.primary)
    }
}
