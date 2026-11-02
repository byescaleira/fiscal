import Charts
import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct ProfileMoneyChapter: View {
    @Environment(ProfileModel.self) private var profile

    var body: some View {
        if profile.hasExpenses || !profile.expenseYears.isEmpty {
            ProfileBlock(
                title: Text(verbatim: profile.expensesSectionTitle),
                footer: [profile.sourceText(for: ["expenses"])]
            ) {
                if profile.hasExpenses {
                    ProfileExpensesSummary()
                    if !profile.categoryLines.isEmpty {
                        RankedBarChart(
                            String(appLocalized: "By kind of expense"),
                            bars: profile.categoryLines.enumerated().map { $1.ranked(slot: $0) }
                        )
                    }
                    RouteLink(profile.expensesRoute) {
                        Label("Every Expense", systemImage: "list.bullet.rectangle")
                    }
                } else {
                    Text("No receipts this year")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } accessory: {
                ProfileExpenseYearMenu()
            }
        }
    }
}

private struct ProfileExpenseYearMenu: View {
    @Environment(ProfileModel.self) private var profile

    var body: some View {
        if profile.expenseYears.count > 1 {
            Menu {
                Picker(
                    "Year",
                    selection: Binding(
                        get: { profile.expenseYear },
                        set: { year in Task { await profile.selectExpenseYear(year) } })
                ) {
                    ForEach(profile.expenseYears, id: \.self) { year in
                        Text(verbatim: String(year)).tag(year)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                HStack(spacing: .spaceXS) {
                    Text(verbatim: profile.yearText)
                        .lineLimit(1)
                        .fixedSize()
                    Image(systemName: "chevron.up.chevron.down")
                        .imageScale(.small)
                        .accessibilityHidden(true)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.primary)
                .frame(minHeight: .badgeL)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .tint(Color.primary)
            .accessibilityLabel(Text("Year"))
            .accessibilityValue(Text(verbatim: profile.yearText))
            .sensoryFeedback(.selection, trigger: profile.expenseYear)
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
    }
}

private struct ProfileMonthChart: View {
    @Environment(ProfileModel.self) private var profile
    @ReducesMotion private var reduceMotion
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
            withAnimation(reduceMotion ? nil : .chartReveal(0)) { revealed = true }
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
