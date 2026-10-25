import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public struct MonthPicker: View {
    @Binding private var selection: YearMonth
    @State private var year: Int
    @State private var isExpanded: Bool
    @State private var edge: Edge = .trailing
    @Environment(\.appTint) private var appTint
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let unavailable: Set<YearMonth>
    private let unavailableTitle: String

    public init(
        selection: Binding<YearMonth>, unavailable: Set<YearMonth> = [],
        unavailableTitle: String = "", isExpanded: Bool = false
    ) {
        _selection = selection
        _year = State(initialValue: selection.wrappedValue.year)
        _isExpanded = State(initialValue: isExpanded)
        self.unavailable = unavailable
        self.unavailableTitle = unavailableTitle
    }

    private var calendar: MonthCalendar {
        MonthCalendar(
            year: year, selection: selection, unavailable: unavailable,
            unavailableTitle: unavailableTitle)
    }

    public var body: some View {
        MonthSummaryRow(calendar: calendar, isExpanded: isExpanded, tint: appTint) {
            withAnimation(reduceMotion ? nil : .snappy) { isExpanded.toggle() }
        }
        .sensoryFeedback(.selection, trigger: selection)
        .onChange(of: selection) { _, value in year = value.year }
        if isExpanded {
            VStack(spacing: .spaceS) {
                MonthYearBar(
                    calendar: calendar, tint: appTint, move: move, jumpToToday: jumpToToday)
                MonthGrid(calendar: calendar, tint: appTint) { selection = $0 }
                    .id(year)
                    .transition(reduceMotion ? .opacity : .push(from: edge))
                    #if !os(tvOS)
                        .gesture(swipe)
                    #endif
            }
            .clipped()
            .sensoryFeedback(.selection, trigger: year)
        }
    }

    #if !os(tvOS)
        private var swipe: some Gesture {
            DragGesture(minimumDistance: .spaceXL).onEnded { value in
                let width = value.translation.width
                guard abs(width) > abs(value.translation.height) else { return }
                move(by: width < 0 ? 1 : -1)
            }
        }
    #endif

    private func move(by years: Int) {
        edge = years > 0 ? .trailing : .leading
        withAnimation(reduceMotion ? nil : .snappy) { year += years }
    }

    private func jumpToToday() {
        let today = calendar.today
        if today.year != year { edge = today.year > year ? .trailing : .leading }
        withAnimation(reduceMotion ? nil : .snappy) {
            year = today.year
            selection = today
        }
    }
}

private struct MonthSummaryRow: View {
    let calendar: MonthCalendar
    let isExpanded: Bool
    let tint: Color
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: .spaceM) {
                VStack(alignment: .leading, spacing: .spaceHairline) {
                    Text(calendar.selectionTitle)
                        .font(.rowTitle)
                        .foregroundStyle(isExpanded ? tint : Color.primary)
                        .contentTransition(.interpolate)
                    Text(calendar.relativeTitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .contentTransition(.interpolate)
                }
                Spacer(minLength: .spaceS)
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .frame(minHeight: .rowHeight)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

private struct MonthYearBar: View {
    let calendar: MonthCalendar
    let tint: Color
    let move: (Int) -> Void
    let jumpToToday: () -> Void

    var body: some View {
        HStack(spacing: .space2XS) {
            Text(calendar.yearTitle)
                .font(.headline)
                .contentTransition(.numericText(value: Double(calendar.year)))
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: move(1)
                    case .decrement: move(-1)
                    @unknown default: break
                    }
                }
            Spacer(minLength: .spaceS)
            if calendar.canJumpToToday {
                Button("This Month", action: jumpToToday)
                    .font(.subheadline.weight(.semibold))
                    .tint(tint)
                    .transition(.opacity)
            }
            Group {
                Button("Previous Year", systemImage: "chevron.left") { move(-1) }
                Button("Next Year", systemImage: "chevron.right") { move(1) }
            }
            .labelStyle(.iconOnly)
            .font(.headline)
            .tint(tint)
            .frame(minWidth: .rowHeight, minHeight: .rowHeight)
            .contentShape(.rect)
        }
        .buttonStyle(.borderless)
    }
}

private struct MonthGrid: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var namespace
    let calendar: MonthCalendar
    let tint: Color
    let select: (YearMonth) -> Void

    var body: some View {
        let count = MonthCalendar.columns(
            isAccessibilitySize: dynamicTypeSize.isAccessibilitySize,
            isWide: horizontalSizeClass == .regular)
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: .spaceXS), count: count),
            spacing: .spaceXS
        ) {
            ForEach(calendar.choices) { choice in
                MonthCell(choice: choice, tint: tint, namespace: namespace) {
                    select(choice.month)
                }
            }
        }
        .padding(.bottom, .spaceS)
        .animation(reduceMotion ? nil : .snappy, value: calendar.selection)
    }
}

private struct MonthCell: View {
    let choice: MonthChoice
    let tint: Color
    let namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: .spaceHairline) {
                Text(choice.title)
                    .font(.subheadline.weight(weight))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Circle()
                    .fill(choice.isAvailable ? Color.clear : dotColor)
                    .frame(width: .spaceXS, height: .spaceXS)
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: .rowHeight)
            .background { background }
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(choice.fullTitle)
        .accessibilityValue(choice.detail)
        .accessibilityAddTraits(choice.isSelected ? .isSelected : [])
    }

    private var weight: Font.Weight {
        choice.isSelected || choice.time == .current ? .bold : .medium
    }

    private var foreground: Color {
        if choice.isSelected { return .white }
        if !choice.isAvailable { return .secondary }
        switch choice.time {
        case .current: return tint
        case .past: return .secondary
        case .future: return .primary
        }
    }

    private var dotColor: Color {
        choice.isSelected ? .white : .secondary
    }

    @ViewBuilder private var background: some View {
        if choice.isSelected {
            Capsule()
                .fill(choice.isAvailable ? tint : Color.negative)
                .matchedGeometryEffect(id: "selection", in: namespace)
        } else if choice.time == .current {
            Capsule().fill(tint.opacity(.opacityTint))
        }
    }
}
