import SwiftUI

public enum RailPlacement: Hashable, Sendable {
    case listRow
    case padded(CGFloat)
}

public struct EdgeToEdgeRail<Content: View>: View {
    @Environment(\.isGroupedColumn) private var isGroupedColumn
    private let placement: RailPlacement
    private let spacing: CGFloat
    private let alignment: VerticalAlignment
    private let isLazy: Bool
    private let snaps: Bool
    private let content: Content

    public init(
        _ placement: RailPlacement = .listRow, spacing: CGFloat = .spaceM,
        alignment: VerticalAlignment = .top, lazy: Bool = false, snaps: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.placement = placement
        self.spacing = spacing
        self.alignment = alignment
        self.isLazy = lazy
        self.snaps = snaps
        self.content = content()
    }

    public var body: some View {
        ScrollView(.horizontal) {
            stack
                .scrollTargetLayout()
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, .railRoom)
        }
        .scrollIndicators(.hidden)
        .railSnapping(snaps)
        .contentMargins(.horizontal, margin, for: .scrollContent)
        .scrollClipDisabled(!isGroupedColumn)
        .padding(.horizontal, -bleed)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .railSectionMargins(placement == .listRow && !isGroupedColumn)
    }

    @ViewBuilder private var stack: some View {
        if isLazy {
            LazyHStack(alignment: alignment, spacing: spacing) { content }
        } else {
            HStack(alignment: alignment, spacing: spacing) { content }
        }
    }

    private var margin: CGFloat {
        switch placement {
        case .listRow: .railListMargin
        case .padded(let inset): inset
        }
    }

    private var bleed: CGFloat {
        switch placement {
        case .listRow: isGroupedColumn ? GroupedMetrics.rowInset : .zero
        case .padded(let inset): inset
        }
    }
}

extension View {
    @ViewBuilder public func railSectionMargins(_ isFlush: Bool = true) -> some View {
        #if os(iOS)
            listSectionMargins(.horizontal, isFlush ? .zero : nil)
        #else
            self
        #endif
    }

    @ViewBuilder fileprivate func railSnapping(_ snaps: Bool) -> some View {
        if snaps {
            scrollTargetBehavior(.viewAligned)
        } else {
            self
        }
    }
}
