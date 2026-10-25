import FeatureCore
import FiscalDesignSystem
import SwiftUI

public struct MoneyScreen: View {
    @Environment(MoneyModel.self) private var money

    public init() {}

    public var body: some View {
        Group {
            if money.isEmpty {
                MoneyEmptyState()
            }
        }
        .fontDesign(.rounded)
        .navigationTitle("Money")
        .task { await money.load() }
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
