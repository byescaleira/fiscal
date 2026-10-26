import FiscalDesignSystem
import SwiftUI

public struct RouteLink<Label: View>: View {
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section
    private let route: Route
    private let label: Label

    public init(_ route: Route, @ViewBuilder label: () -> Label) {
        self.route = route
        self.label = label()
    }

    public var body: some View {
        Button {
            open(route, in: section)
        } label: {
            HStack(spacing: .spaceM) {
                label.frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
