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
                ForEach(profile.categoryLines) { line in
                    ProfileCategoryRow(line: line)
                }
                DisclosureLink {
                    ProfileExpensesScreen().environment(profile)
                } label: {
                    Label("Every Expense", systemImage: "list.bullet.rectangle")
                }
            } header: {
                Text("Office Allowance in \(String(profile.year))").sectionTitle()
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
        }
        .padding(.vertical, .space2XS)
    }
}

private struct ProfileMonthChart: View {
    @Environment(ProfileModel.self) private var profile

    var body: some View {
        Chart(profile.monthBars) { bar in
            BarMark(
                x: .value("Month", bar.label),
                y: .value("Amount", Double(bar.cents) / 100)
            )
            .foregroundStyle(
                bar.month == profile.highlightedMonth
                    ? Color.primary : Color.secondary.opacity(.opacitySoft)
            )
            .clipShape(.rect(cornerRadius: .space2XS))
            .accessibilityLabel(Text(verbatim: bar.label))
            .accessibilityValue(Text(verbatim: bar.value))
        }
        .chartYAxis(.hidden)
        .frame(height: .ring * 2)
    }
}

private struct ProfileCategoryRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var filled = false
    let line: ProfileModel.CategoryLine

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceXS) {
            AdaptiveRow(spacing: .spaceS) {
                Text(verbatim: line.category).font(.rowTitle)
                Spacer(minLength: .spaceS)
                Text(verbatim: line.value)
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
            }
            ProgressBar(value: filled ? line.fraction : 0, color: .secondary)
                .animation(reduceMotion ? nil : .smooth(duration: 1), value: filled)
                .onAppear { filled = true }
        }
        .padding(.vertical, .space2XS)
        .accessibilityElement(children: .combine)
    }
}

struct ProfileExpensesScreen: View {
    @Environment(ProfileModel.self) private var profile

    var body: some View {
        List {
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
        .fontDesign(.rounded)
        .navigationTitle("Expenses in \(String(profile.year))")
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
