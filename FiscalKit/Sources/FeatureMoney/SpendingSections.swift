import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct SpendingSection: View {
    @Environment(MoneyModel.self) private var money

    var body: some View {
        Section {
            if let headline = money.spendHeadline {
                Text(verbatim: headline)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !money.spenderPreview.isEmpty {
                SpenderCarousel(spenders: money.spenderPreview)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                if money.spenders.count > money.spenderPreview.count {
                    NavigationLink {
                        MoneySpendersScreen(
                            title: money.scopeName, spenders: money.spenders,
                            year: money.spendYear
                        )
                        .environment(money)
                    } label: {
                        Text("See All (\(money.spenders.count))")
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }
            if !money.categories.isEmpty {
                VStack(alignment: .leading, spacing: .spaceM) {
                    if let headline = money.categoriesHeadline {
                        Text(verbatim: headline)
                            .font(.subheadline.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    CompositionChart(segments: money.quotaComposition)
                }
                .padding(.vertical, .spaceXS)
            }
            if let note = money.spendScopeNote {
                IconRow(verbatim: note, symbol: "map", color: .secondary)
            }
        } header: {
            Text(verbatim: MoneyModel.Section.quota.title).sectionTitle()
        } footer: {
            VStack(alignment: .leading, spacing: .space2XS) {
                Text(
                    "The office allowance pays for work costs, such as flights, office and fuel, with a receipt for each expense. It isn't salary."
                )
                Text(
                    "Above the peer range means spending per month above the third quartile of the same house. It doesn't mean anything irregular; the cap changes by state."
                )
                Text(verbatim: money.sourceLine(for: .quota))
            }
        }
    }
}

private struct SpenderCarousel: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let spenders: [MoneyPlaces.Spender]

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: .spaceM) {
                ForEach(spenders) { SpenderCard(spender: $0) }
            }
        } else {
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: .spaceM) {
                    ForEach(spenders) { spender in
                        SpenderCard(spender: spender)
                            .containerRelativeFrame(.horizontal) { length, _ in
                                min(length * .moneySpenderShare, .moneySpenderCard)
                            }
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
        }
    }
}

private struct SpenderCard: View {
    @Environment(MoneyModel.self) private var money
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section
    let spender: MoneyPlaces.Spender

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceM) {
            Button {
                open(.person(slug: spender.person.slug), in: section)
            } label: {
                identity.contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: money.accessibilityLabel(for: spender)))
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(Text("Opens the profile"))
            Spacer(minLength: 0)
            if let year = money.spendYear {
                Button {
                    open(.expenses(slug: spender.person.slug, year: year), in: section)
                } label: {
                    Label("See Receipts", systemImage: "doc.text.magnifyingglass")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Color.primary)
            }
        }
        .padding(.spaceL)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.groupedRow, in: .rect(cornerRadius: .radiusGroup))
    }

    private var identity: some View {
        let card = spender.person
        return VStack(alignment: .leading, spacing: .spaceM) {
            HStack(alignment: .top) {
                PersonPortrait(slug: card.slug, name: card.name, party: card.party, size: .ring)
                Spacer(minLength: .spaceS)
                PeerBadge(band: spender.band)
            }
            VStack(alignment: .leading, spacing: .space2XS) {
                Text(verbatim: card.name)
                    .font(.headline)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: .spaceS) {
                    PartyMark(card.party)
                    Text(verbatim: "\(card.officeTitle) · \(card.uf.uppercased(with: .app))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            VStack(alignment: .leading, spacing: .spaceHairline) {
                Text(verbatim: money.monthlyText(spender.monthlyCents))
                    .font(.scoreboardNumber)
                    .monospacedDigit()
                    .amountLine()
                Text(verbatim: money.medianText(spender))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let category = spender.topCategory {
                Label {
                    Text(verbatim: category)
                        .lineLimit(2)
                } icon: {
                    Image(systemName: MoneyKind.category(category).symbol)
                }
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
            }
        }
    }
}

struct MoneySpendersScreen: View {
    @Environment(MoneyModel.self) private var money
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section
    let title: String
    let spenders: [MoneyPlaces.Spender]
    let year: Int?

    var body: some View {
        AdaptiveList {
            Section {
                ForEach(spenders) { spender in
                    Button {
                        open(.person(slug: spender.person.slug), in: section)
                    } label: {
                        SpenderRow(spender: spender)
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(verbatim: money.accessibilityLabel(for: spender)))
                    .accessibilityAddTraits(.isButton)
                }
            } footer: {
                Text(verbatim: money.sourceLine(for: .quota))
            }
        }
        .fontDesign(.rounded)
        .navigationTitle(Text(verbatim: title))
        .toolbarTitleDisplayMode(.inline)
    }
}

private struct SpenderRow: View {
    @Environment(MoneyModel.self) private var money
    let spender: MoneyPlaces.Spender

    var body: some View {
        let card = spender.person
        AdaptiveRow(spacing: .spaceM) {
            HStack(spacing: .spaceM) {
                PersonPortrait(slug: card.slug, name: card.name, party: card.party, size: .badgeL)
                VStack(alignment: .leading, spacing: .spaceHairline) {
                    Text(verbatim: card.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                    HStack(spacing: .spaceS) {
                        PartyMark(card.party)
                        Text(verbatim: card.uf.uppercased(with: .app))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer(minLength: .spaceS)
            VStack(alignment: .trailing, spacing: .spaceHairline) {
                Text(verbatim: money.monthlyText(spender.monthlyCents))
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                Text(verbatim: money.medianText(spender))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, .space2XS)
        .contentShape(.rect)
    }
}
