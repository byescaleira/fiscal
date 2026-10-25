import SwiftUI

public struct AdaptiveList<SelectionValue: Hashable, Content: View>: View {
    private let selection: Binding<Set<SelectionValue>>?
    private let columnWidth: CGFloat
    private let content: Content
    @State private var columns = 1

    public init(
        selection: Binding<Set<SelectionValue>>?, columnWidth: CGFloat = 320,
        @ViewBuilder content: () -> Content
    ) {
        self.selection = selection
        self.columnWidth = columnWidth
        self.content = content()
    }

    public var body: some View {
        Group {
            if columns > 1 {
                ScrollView {
                    Group(sections: content) { sections in
                        HStack(alignment: .top, spacing: GroupedMetrics.columnSpacing) {
                            ForEach(0..<columns, id: \.self) { column in
                                LazyVStack(spacing: GroupedMetrics.sectionSpacing) {
                                    ForEach(sections.column(column, of: columns)) {
                                        GroupedSection(section: $0)
                                    }
                                }
                            }
                        }
                        .padding(GroupedMetrics.margin)
                    }
                }
                .background(.groupedBackground)
                .environment(\.isGroupedColumn, true)
            } else {
                List(selection: selection) { content }
            }
        }
        .onGeometryChange(for: Int.self) { [columnWidth] proxy in
            GroupedMetrics.columns(in: proxy.size.width, columnWidth: columnWidth)
        } action: {
            columns = $0
        }
    }
}

extension AdaptiveList where SelectionValue == Never {
    public init(columnWidth: CGFloat = 320, @ViewBuilder content: () -> Content) {
        self.init(selection: nil, columnWidth: columnWidth, content: content)
    }
}

extension SectionCollection {
    fileprivate func column(_ column: Int, of count: Int) -> [SectionConfiguration] {
        enumerated().filter { $0.offset % count == column }.map(\.element)
    }
}

extension GroupedMetrics {
    fileprivate static func columns(in width: CGFloat, columnWidth: CGFloat) -> Int {
        let available = width - margin * 2
        let fit = (available + columnSpacing) / (columnWidth + columnSpacing)
        return max(1, Int(fit))
    }
}
