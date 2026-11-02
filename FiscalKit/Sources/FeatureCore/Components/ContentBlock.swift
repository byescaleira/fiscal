import FiscalDesignSystem
import SwiftUI

public struct ContentBlock<Content: View, Accessory: View>: View {
    private let title: Text?
    private let footer: [String?]
    private let accessory: Accessory
    private let content: Content

    public init(
        title: Text? = nil, footer: [String?] = [], @ViewBuilder content: () -> Content,
        @ViewBuilder accessory: () -> Accessory = { EmptyView() }
    ) {
        self.title = title
        self.footer = footer
        self.content = content()
        self.accessory = accessory()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            if let title {
                AdaptiveStack(spacing: .spaceS) {
                    title
                        .sectionTitle()
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 0)
                    accessory
                }
            }
            VStack(alignment: .leading, spacing: 0) {
                Group(subviews: content) { rows in
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        if index > 0 { Divider() }
                        row.padding(.vertical, .spaceM)
                    }
                }
            }
            .padding(.horizontal, .spaceL)
            .padding(.vertical, .spaceXS)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.plainRow, in: .rect(cornerRadius: .radiusGroup))
            if footer.contains(where: { $0 != nil }) {
                ContentFooter(lines: footer)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, .spaceL)
            }
        }
    }
}

public struct ContentFooter: View {
    private let lines: [String?]

    public init(lines: [String?]) {
        self.lines = lines
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: .space2XS) {
            ForEach(Array(lines.compactMap(\.self).enumerated()), id: \.offset) { _, line in
                Text(verbatim: line)
            }
        }
    }
}
