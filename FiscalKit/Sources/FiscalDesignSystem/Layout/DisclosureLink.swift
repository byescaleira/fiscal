import SwiftUI

extension EnvironmentValues {
    @Entry public var isGroupedColumn = false
}

public struct DisclosureLink<Label: View, Destination: View>: View {
    @Environment(\.isGroupedColumn) private var isGroupedColumn
    private let destination: Destination
    private let label: Label

    public init(@ViewBuilder destination: () -> Destination, @ViewBuilder label: () -> Label) {
        self.destination = destination()
        self.label = label()
    }

    public var body: some View {
        if isGroupedColumn {
            NavigationLink {
                destination
            } label: {
                HStack(spacing: 12) {
                    label.frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.forward")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink(destination: { destination }, label: { label })
        }
    }
}
