import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct ExpensesToolbar: ToolbarContent {
    @Environment(ExpensesModel.self) private var expenses
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section

    var body: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            ExpensesFilterMenu()
        }
        FixedToolbarSpacer(placement: .primaryAction)
        ToolbarItem(placement: .primaryAction) {
            Button {
                open(expenses.shareRoute, in: section)
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .disabled(expenses.isEmpty)
            .tint(Color.primary)
        }
    }
}

private struct ExpensesFilterMenu: View {
    @Environment(ExpensesModel.self) private var expenses

    var body: some View {
        Menu {
            if expenses.years.count > 1 {
                Picker("Year", selection: year) {
                    ForEach(expenses.years.reversed(), id: \.self) { year in
                        Text(verbatim: String(year)).tag(year)
                    }
                }
                .pickerStyle(.inline)
            }
            if !expenses.categoryNames.isEmpty {
                ExpensesKindPicker()
            }
            if expenses.hasFilter {
                Divider()
                Button("Clear Filters", systemImage: "eraser.line.dashed") {
                    expenses.clearFilters()
                }
            }
        } label: {
            Label("Filters", systemImage: "line.3.horizontal.decrease")
                .labelStyle(.iconOnly)
                .foregroundStyle(Color.primary)
                .quietBounce(value: expenses.hasFilter)
        }
        .accessibilityValue(Text(verbatim: expenses.scopeTitle))
        .menuStyle(.button)
        .buttonStyle(.plain)
        .tint(Color.primary)
        .badge(expenses.activeFilterCount)
        .disabled(!expenses.canFilter)
    }

    private var year: Binding<Int> {
        Binding(
            get: { expenses.year },
            set: { year in Task { await expenses.select(year: year) } })
    }
}

private struct ExpensesKindPicker: View {
    @Environment(ExpensesModel.self) private var expenses

    var body: some View {
        @Bindable var expenses = expenses
        Picker(selection: $expenses.categoryFilter) {
            Text("All kinds").tag(String?.none)
            ForEach(expenses.categoryNames, id: \.self) { name in
                Text(verbatim: name).tag(String?.some(name))
            }
        } label: {
            Label("Kind of Expense", systemImage: "tag")
        }
        .pickerStyle(.menu)
    }
}
