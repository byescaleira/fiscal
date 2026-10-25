import SwiftUI

public struct SelectionMark: View {
    @Environment(\.appTint) private var appTint
    private let isSelected: Bool

    public init(isSelected: Bool) {
        self.isSelected = isSelected
    }

    public var body: some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.icon(.m))
            .foregroundStyle(isSelected ? appTint : Color.secondary)
            .contentTransition(.symbolEffect(.replace))
            .accessibilityHidden(true)
    }
}
