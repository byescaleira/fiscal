import FiscalDesignSystem
import SwiftUI

public struct GuideStep: Identifiable {
    public let id = UUID()
    let symbol: String
    let color: Color
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    public init(
        _ symbol: String, color: Color, title: LocalizedStringKey, detail: LocalizedStringKey
    ) {
        self.symbol = symbol
        self.color = color
        self.title = title
        self.detail = detail
    }
}

public struct GuideSteps: View {
    private let steps: [GuideStep]

    public init(_ steps: [GuideStep]) {
        self.steps = steps
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: .spaceL) {
            ForEach(steps) { GuideStepRow(step: $0) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .leading) {
            if steps.count > 1 {
                Rectangle()
                    .fill(Color.secondary.opacity(.opacitySoft))
                    .frame(width: .spaceHairline)
                    .padding(.vertical, .badgeM / 2)
                    .padding(.leading, .badgeM / 2 - .spaceHairline / 2)
            }
        }
        .padding(.spaceL)
        .background(.sheetCard, in: .rect(cornerRadius: .radiusL))
        .multilineTextAlignment(.leading)
    }
}

private struct GuideStepRow: View {
    let step: GuideStep

    var body: some View {
        HStack(alignment: .top, spacing: .spaceM) {
            SymbolBadge(step.symbol, color: step.color, size: .badgeM, style: .filled)
            VStack(alignment: .leading, spacing: .spaceHairline) {
                Text(step.title).font(.rowTitle)
                Text(step.detail).font(.rowDetail).foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

public struct GuideLink: View {
    private let title: LocalizedStringKey
    private let symbol: String
    private let url: URL

    public init(_ title: LocalizedStringKey, symbol: String, url: URL) {
        self.title = title
        self.symbol = symbol
        self.url = url
    }

    public var body: some View {
        Link(destination: url) {
            Label(title, systemImage: symbol)
                .font(.buttonLabel)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .fontDesign(.rounded)
    }
}
