import FiscalDesignSystem
import SwiftUI

public struct GuidePage<Artwork: View, Content: View>: View {
    private let title: Text
    private let message: Text
    private let artwork: Artwork
    private let content: Content

    public init(
        title: LocalizedStringKey, message: LocalizedStringKey,
        @ViewBuilder artwork: () -> Artwork, @ViewBuilder content: () -> Content = { EmptyView() }
    ) {
        self.title = Text(title)
        self.message = Text(message)
        self.artwork = artwork()
        self.content = content()
    }

    public init(
        verbatim title: String, message: String,
        @ViewBuilder artwork: () -> Artwork, @ViewBuilder content: () -> Content = { EmptyView() }
    ) {
        self.title = Text(verbatim: title)
        self.message = Text(verbatim: message)
        self.artwork = artwork()
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: .spaceXL) {
            VStack(spacing: .spaceS) {
                title.font(.titleLarge)
                message.font(.body).foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            artwork
                .frame(maxWidth: content is EmptyView ? 320 : 220)
                .accessibilityHidden(true)
            content
        }
        .frame(maxWidth: .infinity)
    }
}
