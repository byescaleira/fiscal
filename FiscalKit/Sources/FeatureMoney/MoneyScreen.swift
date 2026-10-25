import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public struct MoneyScreen: View {
    @Environment(MoneyModel.self) private var money

    public init() {}

    public var body: some View {
        PublicDataContent(
            phase: money.phase, isEmpty: money.isEmpty, retry: { await money.load() }
        ) {
            AdaptiveList {
                MoneyHeroSection()
                ForEach(money.sections) { section in
                    switch section {
                    case .quota:
                        QuotaCategoriesSection()
                        QuotaExplainerSection()
                    case .salaries: SalariesSection()
                    case .campaigns: CampaignsSection()
                    case .revenue: RevenueSection()
                    }
                }
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

private struct MoneyHeroSection: View {
    @Environment(MoneyModel.self) private var money

    var body: some View {
        Section {
            if let hero = money.hero {
                MoneyCard(
                    LinearGradient(
                        colors: [
                            .scoreboard, .scoreboard, .scoreboardAccent.opacity(.opacitySoft),
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing)
                ) {
                    MoneyHeroValue(
                        chip: hero.chip, value: hero.value, cents: hero.cents,
                        caption: hero.caption, accent: .scoreboardAccent)
                    Divider().overlay(.white.opacity(.opacitySoft))
                    AdaptiveRow(spacing: .spaceM) {
                        MoneyScoreSide(label: "Chamber", value: hero.chamber, alignment: .leading)
                        Spacer(minLength: .spaceS)
                        MoneyScoreSide(label: "Senate", value: hero.senate, alignment: .trailing)
                    }
                    RevealingBar(value: hero.chamberShare, color: .scoreboardAccent)
                        .accessibilityHidden(true)
                }
            }
        } header: {
            if let stance = money.stance {
                MoneyLensHeader(stance: stance, note: money.lensNote)
            }
        } footer: {
            Text(verbatim: money.sourceLine(for: .quota))
        }
    }
}

private struct MoneyLensHeader: View {
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section
    let stance: PoliticalStance
    let note: String?

    var body: some View {
        AdaptiveRow(spacing: .spaceS) {
            Button {
                open(.lens, in: section)
            } label: {
                LensBadge(stance)
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("Opens what your lens changes"))
            if let note {
                Text(verbatim: note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .textCase(nil)
        .padding(.bottom, .spaceS)
    }
}

private struct QuotaCategoriesSection: View {
    @Environment(MoneyModel.self) private var money

    var body: some View {
        if !money.categories.isEmpty {
            Section {
                VStack(alignment: .leading, spacing: .spaceM) {
                    if let headline = money.categoriesHeadline {
                        Text(verbatim: headline).font(.headline)
                    }
                    CompositionChart(segments: money.quotaComposition)
                }
                .padding(.vertical, .spaceXS)
            } header: {
                Text("Where the allowance goes").sectionTitle()
            } footer: {
                VStack(alignment: .leading, spacing: .space2XS) {
                    Text(
                        "Totals by kind of expense, adding up every deputy and senator. Touch the bar or a kind to see its share."
                    )
                    Text(verbatim: money.sourceLine(for: .quota))
                }
            }
        }
    }
}

private struct QuotaExplainerSection: View {
    var body: some View {
        Section {
            IconRow(
                "Money to do the job",
                detail:
                    "A monthly amount for flights, office, phone, fuel and telling voters what the mandate does.",
                symbol: "briefcase", color: .retroDenim)
            IconRow(
                "Every expense needs a receipt",
                detail:
                    "The office pays and asks to be refunded with an invoice. The Chamber and the Senate publish each one.",
                symbol: "doc.text.magnifyingglass", color: .retroTeal)
            IconRow(
                "It isn't salary",
                detail:
                    "The allowance only pays for work costs. Salary is separate and has its own section.",
                symbol: "banknote", color: .retroPlum)
            IconRow(
                "The cap changes by state",
                detail:
                    "Deputies from states farther from Brasília get a higher monthly cap, because flights cost more.",
                symbol: "map", color: .retroBrown)
        } header: {
            Text("What is the office allowance?").sectionTitle()
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
            IconRow("Office allowance", symbol: "creditcard", color: .retroDenim)
            IconRow("Salaries", symbol: "banknote", color: .retroPlum)
            IconRow("Campaigns", symbol: "building.columns", color: .retroTeal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.groupedBackground)
    }
}
