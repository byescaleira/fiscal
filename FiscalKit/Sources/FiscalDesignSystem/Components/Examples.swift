import SwiftUI

public struct GuideExample<Content: View>: View {
    private let background: Color
    private let content: Content

    public init(background: Color = .sheetCard, @ViewBuilder content: () -> Content) {
        self.background = background
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: .spaceM) { content }
            .padding(.spaceL)
            .frame(maxWidth: 420)
            .background(background, in: .rect(cornerRadius: .radiusL))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

public struct ExampleRow: View {
    private let symbol: String?
    private let color: Color
    private let title: String
    private let detail: String?
    private let value: String
    private let valueColor: Color

    public init(
        _ title: String, detail: String? = nil, value: String, valueColor: Color = .primary,
        symbol: String? = nil, color: Color = .secondary
    ) {
        self.title = title
        self.detail = detail
        self.value = value
        self.valueColor = valueColor
        self.symbol = symbol
        self.color = color
    }

    public var body: some View {
        HStack(spacing: .spaceM) {
            if let symbol {
                SymbolBadge(symbol, color: color, size: .badgeM)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.subheadline.weight(.semibold))
                if let detail {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
            Spacer(minLength: .spaceS)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(valueColor)
                .lineLimit(1)
        }
    }
}

public struct ExampleBar: View {
    @Environment(\.locale) private var locale
    private let title: String
    private let detail: String?
    private let ratio: Double
    private let color: Color

    public init(_ title: String, detail: String? = nil, ratio: Double, color: Color) {
        self.title = title
        self.detail = detail
        self.ratio = ratio
        self.color = color
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: .spaceXS) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.subheadline.weight(.semibold))
                Spacer()
                Text(
                    detail ?? ratio.formatted(.percent.precision(.fractionLength(0)).locale(locale))
                )
                .font(.subheadline.weight(.bold))
                .foregroundStyle(color)
            }
            .lineLimit(1)
            ProgressBar(value: ratio, color: color)
        }
    }
}

public struct ExampleHeadline: View {
    @Environment(\.appTint) private var appTint
    private let chip: String?
    private let value: String
    private let detail: String?

    public init(chip: String? = nil, value: String, detail: String? = nil) {
        self.chip = chip
        self.value = value
        self.detail = detail
    }

    public var body: some View {
        VStack(spacing: .spaceXS) {
            if let chip { Chip(chip.uppercased(), color: appTint) }
            Text(value)
                .font(.title.weight(.black))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let detail {
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
