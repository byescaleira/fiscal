import FiscalDesignSystem
import SwiftUI

public struct ShareItemButton: View {
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section
    private let route: Route
    private let label: Text

    public init(_ route: Route, label: Text) {
        self.route = route
        self.label = label
    }

    public var body: some View {
        Button {
            open(route, in: section)
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(minWidth: .badgeL, minHeight: .badgeL)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

private struct ShareItemMenu: ViewModifier {
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section
    let route: Route?
    let label: Text

    func body(content: Content) -> some View {
        if let route {
            content.contextMenu {
                Button {
                    open(route, in: section)
                } label: {
                    Label {
                        label
                    } icon: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        } else {
            content
        }
    }
}

extension View {
    public func shareItemMenu(_ route: Route?, label: Text) -> some View {
        modifier(ShareItemMenu(route: route, label: label))
    }
}
