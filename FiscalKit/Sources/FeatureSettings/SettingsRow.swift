import FiscalDesignSystem
import SwiftUI

public struct SettingsRow<Destination: View>: View {
    private let title: LocalizedStringKey
    private let symbol: String
    private let color: Color
    private let value: String?
    private let destination: Destination

    public init(
        _ title: LocalizedStringKey, symbol: String, color: Color, value: String? = nil,
        @ViewBuilder destination: () -> Destination
    ) {
        self.title = title
        self.symbol = symbol
        self.color = color
        self.value = value
        self.destination = destination()
    }

    public var body: some View {
        DisclosureLink {
            destination
        } label: {
            IconRow(title, symbol: symbol, color: color, value: value)
        }
    }
}

public struct SettingsPage<Content: View>: View {
    private let title: LocalizedStringKey
    private let content: Content

    public init(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    public var body: some View {
        Group {
            #if os(macOS)
                Form { content }.formStyle(.grouped)
            #else
                AdaptiveList { content }
            #endif
        }
        .navigationTitle(title)
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
