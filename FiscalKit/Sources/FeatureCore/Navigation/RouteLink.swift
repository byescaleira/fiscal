import FiscalDesignSystem
import SwiftUI

public struct RouteLink<Label: View>: View {
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section
    private let route: Route
    private let showsChevron: Bool
    private let label: Label

    public init(_ route: Route, showsChevron: Bool = true, @ViewBuilder label: () -> Label) {
        self.route = route
        self.showsChevron = showsChevron
        self.label = label()
    }

    public var body: some View {
        Button {
            open(route, in: section)
        } label: {
            if showsChevron {
                HStack(spacing: .spaceM) {
                    label.frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.forward")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .contentShape(.rect)
            } else {
                label
            }
        }
        .buttonStyle(.plain)
    }
}
