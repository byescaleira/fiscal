import SwiftUI

extension View {
    public func emphasisTitle(_ title: Text) -> some View {
        modifier(EmphasisTitle(title: title))
    }

    public func emphasisTitle(_ key: LocalizedStringKey) -> some View {
        emphasisTitle(Text(key))
    }

    @_disfavoredOverload
    public func emphasisTitle<S: StringProtocol>(_ title: S) -> some View {
        emphasisTitle(Text(title))
    }
}

private struct EmphasisTitle: ViewModifier {
    let title: Text

    func body(content: Content) -> some View {
        #if os(iOS)
            content
                .navigationTitle(title)
                .toolbar {
                    ToolbarItem(placement: .largeTitle) {
                        title
                            .font(.emphasis(.largeTitle, weight: .bold))
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityAddTraits(.isHeader)
                    }
                }
        #else
            content.navigationTitle(title)
        #endif
    }
}
