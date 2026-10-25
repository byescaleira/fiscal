import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public struct ExpensesScreen: View {
    @Environment(ExpensesModel.self) private var expenses
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section

    public init() {}

    public var body: some View {
        PublicDataContent(
            phase: expenses.phase, isEmpty: expenses.isEmpty, retry: { await expenses.load() }
        ) {
            AdaptiveList {
                ExpensesHeroSection()
                ExpensesMonthsSection()
                ExpensesCategoriesSection()
                ExpensesFilterSection()
                ForEach(expenses.groups) { ExpensesMonthSection(group: $0) }
            }
        } empty: {
            ExpensesEmptyState()
        }
        .fontDesign(.rounded)
        .navigationTitle(Text(verbatim: expenses.title))
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            if expenses.years.count > 1 {
                ToolbarItem(placement: .primaryAction) { ExpensesYearMenu() }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    open(expenses.shareRoute, in: section)
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .disabled(expenses.isEmpty)
            }
        }
        .refreshable { await expenses.load() }
        .task { await expenses.load() }
    }
}

private struct ExpensesHeroSection: View {
    @Environment(ExpensesModel.self) private var expenses

    var body: some View {
        Section {
            MoneyCard(heroBackground) {
                if let header = expenses.header {
                    ExpensesIdentity(slug: expenses.slug, header: header)
                }
                MoneyHeroValue(
                    chip: expenses.chip, value: expenses.total, cents: expenses.totalCents,
                    caption: expenses.receiptsCaption, accent: .white)
            }

        } footer: {
            Text(verbatim: expenses.sourceLine)
        }
    }

    private var heroBackground: AnyShapeStyle {
        guard let party = expenses.header?.party else {
            return AnyShapeStyle(Color.scoreboard.gradient)
        }
        return AnyShapeStyle(PartyPalette.of(party: party).gradient)
    }
}

private struct ExpensesIdentity: View {
    let slug: String
    let header: ExpensesModel.Header

    var body: some View {
        AdaptiveRow(spacing: .spaceM) {
            PersonPortrait(slug: slug, name: header.name, party: header.party, size: .badgeXL)
                .overlay(Circle().stroke(.white.opacity(.opacityStrong), lineWidth: .spaceHairline))
            VStack(alignment: .leading, spacing: .spaceHairline) {
                Text(verbatim: header.name)
                    .font(.titleMedium)
                    .foregroundStyle(.white)
                Text(verbatim: header.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ExpensesYearMenu: View {
    @Environment(ExpensesModel.self) private var expenses

    var body: some View {
        Menu {
            Picker(
                "Year",
                selection: Binding(
                    get: { expenses.year },
                    set: { year in Task { await expenses.select(year: year) } })
            ) {
                ForEach(expenses.years, id: \.self) { year in
                    Text(verbatim: String(year)).tag(year)
                }
            }
            .pickerStyle(.inline)
        } label: {
            HStack(spacing: .spaceXS) {
                Image(systemName: "calendar")
                Text(verbatim: String(expenses.year)).monospacedDigit()
            }
            .font(.subheadline.weight(.semibold))
        }
        .accessibilityLabel(Text("Year"))
        .accessibilityValue(Text(verbatim: String(expenses.year)))
    }
}

private struct ExpensesMonthsSection: View {
    @Environment(ExpensesModel.self) private var expenses

    var body: some View {
        @Bindable var expenses = expenses
        Section {
            VStack(alignment: .leading, spacing: .spaceM) {
                if let month = expenses.highlightedMonth {
                    VStack(alignment: .leading, spacing: .spaceHairline) {
                        Text(verbatim: month.name)
                            .font(.headline)
                        Text(verbatim: month.value)
                            .font(.amountTitle)
                            .monospacedDigit()
                            .contentTransition(.numericText(value: month.reais))
                            .amountLine()
                    }
                    .accessibilityElement(children: .combine)
                }
                MonthlyBarsChart(
                    months: expenses.months, highlighted: expenses.highlightedMonth?.month,
                    averageReais: expenses.averageCents.map { Double($0) / 100 },
                    selection: $expenses.selectedMonth)
            }
            .padding(.vertical, .spaceXS)
        } header: {
            Text("By month").sectionTitle()
        } footer: {
            VStack(alignment: .leading, spacing: .space2XS) {
                if let peak = expenses.peakText { Text(verbatim: peak) }
                Text("Touch a month to see its total. The dashed line is the monthly average.")
                Text(verbatim: expenses.averageText)
            }
        }
    }
}

private struct ExpensesCategoriesSection: View {
    @Environment(ExpensesModel.self) private var expenses

    var body: some View {
        if !expenses.categories.isEmpty {
            Section {
                AmountBarsChart(bars: expenses.categories)
                    .padding(.vertical, .spaceXS)
            } header: {
                Text("By kind of expense").sectionTitle()
            }
        }
    }
}

private struct ExpensesEmptyState: View {
    var body: some View {
        EmptyStateView(
            title: "No receipts this year",
            description:
                "When the house publishes the receipts paid with the office allowance, they show up here with supplier and CNPJ."
        ) {
            IconRow(
                verbatim: "LATAM Linhas Aéreas", detail: "Passagens aéreas", symbol: "airplane",
                color: .retroDenim)
            IconRow(
                verbatim: "Gráfica Planalto", detail: "Divulgação", symbol: "megaphone",
                color: .retroOrange)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.groupedBackground)
    }
}
