import FiscalDesignSystem
import SwiftUI

public struct SettingsRow<Destination: View>: View {
    private let title: LocalizedStringKey
    private let detail: LocalizedStringKey?
    private let symbol: String
    private let color: Color
    private let value: String?
    private let destination: Destination

    public init(
        _ title: LocalizedStringKey, detail: LocalizedStringKey? = nil, symbol: String,
        color: Color, value: String? = nil, @ViewBuilder destination: () -> Destination
    ) {
        self.title = title
        self.detail = detail
        self.symbol = symbol
        self.color = color
        self.value = value
        self.destination = destination()
    }

    public var body: some View {
        DisclosureLink {
            destination
        } label: {
            SettingsLabel(title, detail: detail, symbol: symbol, color: color, value: value)
        }
    }
}

public struct SettingsLabel: View {
    private let row: IconRow

    public init(
        _ title: LocalizedStringKey, detail: LocalizedStringKey? = nil, symbol: String,
        color: Color, value: String? = nil
    ) {
        row = IconRow(title, detail: detail, symbol: symbol, color: color, value: value)
    }

    public init(
        verbatim title: String, detail: String? = nil, symbol: String, color: Color,
        value: String? = nil
    ) {
        row = IconRow(verbatim: title, detail: detail, symbol: symbol, color: color, value: value)
    }

    public var body: some View {
        row.contentShape(.rect)
    }
}

struct SettingsExternalLabel: View {
    private let label: SettingsLabel

    init(
        _ title: LocalizedStringKey, detail: LocalizedStringKey? = nil, symbol: String,
        color: Color
    ) {
        label = SettingsLabel(title, detail: detail, symbol: symbol, color: color)
    }

    var body: some View {
        HStack(spacing: .spaceS) {
            label
            Image(systemName: "arrow.up.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
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
        .fontDesign(.rounded)
        .navigationTitle(title)
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
