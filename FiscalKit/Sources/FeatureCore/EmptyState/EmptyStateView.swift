import FiscalDesignSystem
import SwiftUI

public struct EmptyStateView<Example: View>: View {
    private let title: LocalizedStringKey
    private let description: LocalizedStringKey
    private let actionTitle: LocalizedStringKey?
    private let action: (() -> Void)?
    private let example: Example

    public init(
        title: LocalizedStringKey, description: LocalizedStringKey,
        actionTitle: LocalizedStringKey? = nil, action: (() -> Void)? = nil,
        @ViewBuilder example: () -> Example
    ) {
        self.title = title
        self.description = description
        self.actionTitle = actionTitle
        self.action = action
        self.example = example()
    }

    public var body: some View {
        ContentUnavailableView {
            VStack(spacing: .spaceInset) {
                GuideExample(background: Color.secondary.opacity(.opacityFill)) { example }
                    .accessibilityHidden(true)
                Text(title).font(.titleMedium)
            }
        } description: {
            Text(description)
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action).primaryButton()
            }
        }
    }
}
