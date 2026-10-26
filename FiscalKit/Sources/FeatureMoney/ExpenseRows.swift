import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct ExpensesFilterSection: View {
    @Environment(ExpensesModel.self) private var expenses

    var body: some View {
        @Bindable var expenses = expenses
        Section {
            Picker(selection: $expenses.categoryFilter) {
                Text("All kinds").tag(String?.none)
                ForEach(expenses.categoryNames, id: \.self) { name in
                    Text(verbatim: name).tag(String?.some(name))
                }
            } label: {
                Label("Show", systemImage: "line.3.horizontal.decrease")
            }
            .pickerStyle(.menu)
        } header: {
            Text("Receipts").sectionTitle()
        } footer: {
            Text("Each receipt opens the official document published by the house.")
        }
    }
}

struct ExpensesMonthSection: View {
    let group: ExpensesModel.MonthGroup

    var body: some View {
        Section {
            ForEach(group.lines) { ExpenseRow(line: $0) }
        } header: {
            HStack {
                Text(verbatim: group.title)
                Spacer(minLength: .spaceS)
                Text(verbatim: group.total).monospacedDigit()
            }
            .font(.subheadline.weight(.semibold))
            .textCase(nil)
            .accessibilityElement(children: .combine)
        }
    }
}

private struct ExpenseRow: View {
    let line: ExpensesModel.Line

    var body: some View {
        if let url = line.url {
            Link(destination: url) {
                ExpenseRowContent(line: line, opens: true)
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("Opens the official receipt"))
        } else {
            ExpenseRowContent(line: line, opens: false)
        }
    }
}

private struct ExpenseRowContent: View {
    let line: ExpensesModel.Line
    let opens: Bool

    var body: some View {
        AdaptiveRow(spacing: .spaceM) {
            HStack(alignment: .top, spacing: .spaceM) {
                SymbolBadge(line.kind.symbol, color: line.kind.tone.color, size: .badgeM)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: .spaceHairline) {
                    Text(verbatim: line.supplier).font(.rowTitle)
                    Text(verbatim: line.category)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Label {
                        Text(verbatim: line.document)
                            .monospaced(line.isCompany)
                    } icon: {
                        Image(systemName: line.isCompany ? "building.2" : "person")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: .spaceS)
            HStack(spacing: .spaceS) {
                Text(verbatim: line.value)
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                    .amountLine()
                if opens {
                    Image(systemName: "arrow.up.forward.square")
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
            }
        }
        .padding(.vertical, .space2XS)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
