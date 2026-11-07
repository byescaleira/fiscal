import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct ExpensesMonthSection: View {
    @Environment(ExpensesModel.self) private var expenses
    let group: ExpensesModel.MonthGroup
    let isLast: Bool

    var body: some View {
        Section {
            ForEach(group.lines) { ExpenseRow(line: $0) }
        } header: {
            HStack(spacing: .spaceS) {
                HStack {
                    Text(verbatim: group.title)
                    Spacer(minLength: .spaceS)
                    Text(verbatim: group.total).monospacedDigit()
                }
                .accessibilityElement(children: .combine)
                ShareItemButton(
                    expenses.shareRoute(forMonth: group.month),
                    label: Text("Share \(group.title)"))
            }
            .font(.subheadline.weight(.semibold))
            .textCase(nil)
        } footer: {
            if isLast {
                Text("Each receipt opens the official document published by the house.")
            }
        }
    }
}

private struct ExpenseRow: View {
    @Environment(ExpensesModel.self) private var expenses
    let line: ExpensesModel.Line

    var body: some View {
        let route = expenses.shareRoute(for: line)
        Group {
            if let url = line.url {
                ExternalLink(destination: url, showsSymbol: false) {
                    ExpenseRowContent(line: line, opensLink: true)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
            } else {
                ExpenseRowContent(line: line, opensLink: false)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if let route {
                ShareItemButton(route, label: Text("Share the receipt from \(line.supplier)"))
            }
        }
        .shareItemMenu(route, label: Text("Share This Receipt"))
    }
}

private struct ExpenseRowContent: View {
    let line: ExpensesModel.Line
    let opensLink: Bool

    var body: some View {
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
                Text(verbatim: line.value)
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                    .amountLine()
                    .padding(.top, .spaceXS)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if opensLink {
                ExternalLinkSymbol()
                    .font(.footnote.weight(.semibold))
            }
        }
        .padding(.vertical, .space2XS)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
