import FeatureCore
import FiscalDesignSystem
import SwiftUI

public struct MoneyScreen: View {
    @Environment(MoneyModel.self) private var money

    public init() {}

    public var body: some View {
        PublicDataContent(
            phase: money.phase, isEmpty: money.isEmpty, retry: { await money.load() }
        ) {
            AdaptiveList {
                MoneyLinesSection(title: "Office allowance", lines: money.quota)
                MoneyLinesSection(title: "Salaries", lines: money.salaries)
            }
        } empty: {
            MoneyEmptyState()
        }
        .fontDesign(.rounded)
        .navigationTitle("Money")
        .refreshable { await money.load() }
        .task { await money.load() }
    }
}

private struct MoneyLinesSection: View {
    let title: LocalizedStringKey
    let lines: [MoneyModel.Line]

    var body: some View {
        if !lines.isEmpty {
            Section {
                ForEach(lines) { line in
                    LabeledContent {
                        Text(verbatim: line.value).monospacedDigit()
                    } label: {
                        Text(verbatim: line.title)
                        if let detail = line.detail {
                            Text(verbatim: detail)
                        }
                    }
                }
            } header: {
                Text(title).sectionTitle()
            }
        }
    }
}

private struct MoneyEmptyState: View {
    var body: some View {
        EmptyStateView(
            title: "No figures yet",
            description:
                "Office allowances, salaries and campaign money show up here, each with its official source."
        ) {
            IconRow("Office allowance", symbol: "creditcard", color: .retroOlive)
            IconRow("Salaries", symbol: "banknote", color: .retroMustard)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.groupedBackground)
    }
}
