import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct ExpensesMonthSection: View {
    let group: ExpensesModel.MonthGroup
    let isLast: Bool

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
        } footer: {
            if isLast {
                Text("Each receipt opens the official document published by the house.")
            }
        }
    }
}

private struct ExpenseRow: View {
    let line: ExpensesModel.Line

    var body: some View {
        if let url = line.url {
            ExternalLink(destination: url) { ExpenseRowContent(line: line) }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
        } else {
            ExpenseRowContent(line: line)
        }
    }
}

private struct ExpenseRowContent: View {
    let line: ExpensesModel.Line

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
            }
        }
        .padding(.vertical, .space2XS)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
