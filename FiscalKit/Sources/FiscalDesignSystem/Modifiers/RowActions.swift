import SwiftUI

extension View {
    @ViewBuilder public func deleteAction(_ action: @escaping () -> Void) -> some View {
        #if os(tvOS)
            self
        #else
            swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button("Delete", systemImage: "trash.fill", role: .destructive, action: action)
                    .tint(.negative)
            }
        #endif
    }

    @ViewBuilder public func editAction(_ action: @escaping () -> Void) -> some View {
        #if os(tvOS)
            self
        #else
            swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button("Edit", systemImage: "square.and.pencil", action: action)
                    .tint(.info)
            }
        #endif
    }
}
