import Charts
import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct ProfileExpensesSection: View {
    @Environment(ProfileModel.self) private var profile

    var body: some View {
        if profile.hasExpenses {
            Section {
                ProfileExpensesSummary()
                if !profile.categoryLines.isEmpty {
                    RankedBarChart(
                        String(appLocalized: "By kind of expense"),
                        bars: profile.categoryLines.enumerated().map { $1.ranked(slot: $0) }
                    )
                    .padding(.vertical, .spaceXS)
                }
                DisclosureLink {
                    ProfileExpensesScreen().environment(profile)
                } label: {
                    Label("Every Expense", systemImage: "list.bullet.rectangle")
                }
            } header: {
                Text(verbatim: profile.expensesSectionTitle).sectionTitle()
            } footer: {
                ProfileFooter(lines: [profile.sourceText(for: ["expenses"])])
            }
        }
    }
}

private struct ProfileExpensesSummary: View {
    @Environment(ProfileModel.self) private var profile

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            Text(verbatim: profile.expensesTotal)
                .font(.amountTitle)
                .monospacedDigit()
                .amountLine()
            if let headline = profile.expenseHeadline {
                Text(verbatim: headline)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ProfileMonthChart()
            Text("Touch a month to see its total. The dashed line is the monthly average.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, .space2XS)
    }
}

private struct ProfileMonthChart: View {
    @Environment(ProfileModel.self) private var profile
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .caption) private var height: CGFloat = .chartCompactHeight
    @State private var revealed = false
    @State private var scrubbed: String?

    var body: some View {
        let bars = profile.monthBars
        let selected = bars.first { $0.label == scrubbed }
        Chart {
            ForEach(bars) { bar in
                BarMark(
                    x: .value("Month", bar.label),
                    y: .value("Amount", revealed ? bar.reais : 0),
                    width: .ratio(.chartBarWidth)
                )
                .foregroundStyle(style(for: bar))
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: .chartBarCorner, topTrailingRadius: .chartBarCorner)
                )
                .accessibilityLabel(Text(verbatim: bar.name))
                .accessibilityValue(Text(verbatim: bar.value))
            }
            if let average = profile.monthAverageReais {
                RuleMark(y: .value("Average", average))
                    .foregroundStyle(.secondary)
                    .lineStyle(.chartAverage)
                    .accessibilityHidden(true)
            }
            if let selected {
                ProfileMonthSelection(bar: selected)
            }
        }
        .chartXScale(domain: bars.map(\.label))
        .chartYAxis(.hidden)
        .chartXSelection(value: $scrubbed)
        .sensoryFeedback(.selection, trigger: selected?.month)
        .frame(height: height)
        .onAppear {
            withAnimation(reduceMotion ? nil : .smooth(duration: 1)) { revealed = true }
        }
    }

    private func style(for bar: ProfileModel.MonthBar) -> Color {
        bar.month == profile.highlightedMonth
            ? Color.primary : Color.secondary.opacity(.opacitySoft)
    }
}

private struct ProfileMonthSelection: ChartContent {
    let bar: ProfileModel.MonthBar

    var body: some ChartContent {
        RuleMark(x: .value("Selected", bar.label))
            .foregroundStyle(Color.secondary.opacity(.opacitySoft))
            .lineStyle(StrokeStyle(lineWidth: .chartRuleWidth))
            .zIndex(-1)
            .annotation(
                position: .top, spacing: .space2XS,
                overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
            ) {
                ChartCallout(title: bar.name, value: bar.value) { EmptyView() }
            }
            .accessibilityHidden(true)
    }
}

extension ProfileModel.CategoryLine {
    fileprivate func ranked(slot: Int) -> RankedBar {
        RankedBar(
            id: id, title: category, value: fraction, valueText: value,
            details: [shareText, receiptsText], color: ChartPalette.color(at: slot))
    }
}

struct ProfileExpensesScreen: View {
    @Environment(ProfileModel.self) private var profile

    var body: some View {
        List {
            Group {
                Section {
                    ForEach(profile.expenseItems) { expense in
                        ProfileExpenseRow(expense: expense)
                    }
                } header: {
                    Text(verbatim: profile.expensesTotal)
                        .font(.amountTitle)
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .textCase(nil)
                } footer: {
                    ProfileFooter(lines: [profile.sourceText(for: ["expenses"])])
                }
            }
            .surfaceRows()
        }
        .listSurface()
        .navigationTitle(Text(verbatim: profile.expensesScreenTitle))
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

private struct ProfileExpenseRow: View {
    @Environment(ProfileModel.self) private var profile
    let expense: Expense

    var body: some View {
        VStack(alignment: .leading, spacing: .space2XS) {
            AdaptiveRow(spacing: .spaceS) {
                Text(verbatim: expense.supplier).font(.rowTitle)
                Spacer(minLength: .spaceS)
                Text(verbatim: profile.money(expense.cents))
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
            }
            Text(verbatim: profile.expenseDetail(expense))
                .font(.footnote)
                .foregroundStyle(.secondary)
            if let url = expense.url {
                Link(destination: url) {
                    Label("See the Receipt", systemImage: "doc.text.magnifyingglass")
                }
                .font(.footnote)
            }
        }
        .padding(.vertical, .space2XS)
    }
}
