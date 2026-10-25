import FiscalDesignSystem
import SwiftUI

public struct GuideFeature: View {
    private let title: String
    private let detail: String?
    private let color: Color

    public init(title: String, detail: String? = nil, color: Color = .primary) {
        self.title = title
        self.detail = detail
        self.color = color
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: .spaceHairline) {
            Text(title).font(.headline).foregroundStyle(color)
            if let detail {
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, .spaceM)
        .padding(.horizontal, .spaceL)
        .accessibilityElement(children: .combine)
    }
}

public struct GuideFeatureList<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 0) {
            Group(subviews: content) { subviews in
                ForEach(subviews.indices, id: \.self) { index in
                    subviews[index]
                    if index < subviews.count - 1 { Divider().padding(.leading, .spaceL) }
                }
            }
        }
        .multilineTextAlignment(.leading)
        .background(.sheetCard, in: .rect(cornerRadius: .radiusM))
    }
}

public struct GuideValue: View {
    private let label: String
    private let value: String
    private let color: Color

    public init(_ label: String, value: String, color: Color = .primary) {
        self.label = label
        self.value = value
        self.color = color
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: .spaceM) {
            Text(label).foregroundStyle(.secondary)
            Spacer(minLength: .spaceS)
            Text(value).fontWeight(.semibold).foregroundStyle(color).multilineTextAlignment(
                .trailing)
        }
        .font(.subheadline)
        .padding(.vertical, .spaceL)
        .padding(.horizontal, .spaceXL)
    }
}

public struct GuideValueList: View {
    private let rows: [GuideValue]

    public init(_ rows: [GuideValue]) {
        self.rows = rows
    }

    public var body: some View {
        VStack(spacing: 0) {
            ForEach(rows.indices, id: \.self) { index in
                rows[index]
                if index < rows.count - 1 { Divider().padding(.leading, .spaceL) }
            }
        }
        .background(.sheetCard, in: .rect(cornerRadius: .radiusM))
    }
}
