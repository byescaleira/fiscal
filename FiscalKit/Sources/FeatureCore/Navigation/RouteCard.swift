import FiscalDesignSystem
import SwiftUI

public struct RouteChevron: View {
    private let isOnDarkCard: Bool

    public init(isOnDarkCard: Bool = false) {
        self.isOnDarkCard = isOnDarkCard
    }

    public var body: some View {
        Image(systemName: "chevron.forward")
            .font(.footnote.weight(isOnDarkCard ? .bold : .semibold))
            .foregroundStyle(
                isOnDarkCard
                    ? AnyShapeStyle(Color.white.opacity(.opacityStrong)) : AnyShapeStyle(.tertiary)
            )
            .accessibilityHidden(true)
    }
}

public struct RouteCard<Content: View>: View {
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section
    private let route: Route
    private let label: Text
    private let padding: CGFloat
    private let cornerRadius: CGFloat
    private let content: Content

    public init(
        _ route: Route, label: Text, padding: CGFloat, cornerRadius: CGFloat,
        @ViewBuilder content: () -> Content
    ) {
        self.route = route
        self.label = label
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    public var body: some View {
        HStack(spacing: .spaceM) {
            content.frame(maxWidth: .infinity, alignment: .leading)
            RouteChevron().allowsHitTesting(false)
        }
        .padding(padding)
        .background {
            CardBackdropButton(cornerRadius: cornerRadius, label: label) {
                open(route, in: section)
            }
        }
    }
}

public struct CardBackdropButton: View {
    private let cornerRadius: CGFloat
    private let label: Text
    private let action: () -> Void

    public init(cornerRadius: CGFloat, label: Text, action: @escaping () -> Void) {
        self.cornerRadius = cornerRadius
        self.label = label
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Color.clear.contentShape(.rect(cornerRadius: cornerRadius))
        }
        .buttonStyle(CardPressStyle(cornerRadius: cornerRadius))
        .accessibilityLabel(label)
    }
}

private struct CardPressStyle: ButtonStyle {
    let cornerRadius: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Color.primary.opacity(configuration.isPressed ? .opacityFill : 0),
                in: .rect(cornerRadius: cornerRadius))
    }
}
