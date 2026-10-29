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
                MoneyAnswerSection()
                MoneyStaleSection()
                ForEach(money.sections) { section in
                    switch section {
                    case .mandate: MandateSections()
                    case .quota: SpendingSection()
                    case .campaigns: CampaignsSection()
                    case .revenue: RevenueSection()
                    }
                }
            }
        } empty: {
            MoneyEmptyState()
        }
        .emphasisTitle("Money")
        #if !os(visionOS)
            .navigationSubtitle(money.scopeName)
        #endif
        .toolbar { MoneyToolbar() }
        .refreshable { await money.load() }
        .task { await money.load() }
    }
}

private struct MoneyAnswerSection: View {
    @Environment(MoneyModel.self) private var money

    var body: some View {
        Section {
            if let answer = money.answer {
                MoneyAnswerCard(answer: answer)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
        } header: {
            if money.showsLensBadge {
                MoneyLensHeader(note: money.lensNote)
            }
        } footer: {
            Text(verbatim: money.answerSourceLine)
        }
    }
}

private struct MoneyAnswerCard: View {
    @Environment(\.appTint) private var tint
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let answer: MoneyModel.Answer

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceL) {
            VStack(alignment: .leading, spacing: .space2XS) {
                Text(verbatim: answer.kicker)
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(tint)
                    .contentTransition(.opacity)
                HStack(alignment: .firstTextBaseline, spacing: .spaceS) {
                    Text(verbatim: answer.value)
                        .font(.amountHero)
                        .monospacedDigit()
                        .contentTransition(
                            reduceMotion ? .identity : .numericText(value: Double(answer.cents))
                        )
                        .amountLine()
                    Text(verbatim: answer.unit)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Text(verbatim: answer.sentence)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if answer.comparison != nil || answer.fact != nil {
                VStack(alignment: .leading, spacing: .spaceS) {
                    if let comparison = answer.comparison {
                        MoneyAnswerLine(text: comparison, symbol: "equal.circle", tint: tint)
                    }
                    if let fact = answer.fact {
                        MoneyAnswerLine(text: fact, symbol: "creditcard", tint: tint)
                    }
                }
            }
            if let caveat = answer.caveat {
                Label {
                    Text(verbatim: caveat)
                } icon: {
                    Image(systemName: "info.circle")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(.primary)
        .padding(.spaceInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.plainRow, in: .rect(cornerRadius: .radiusGroup))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

private struct MoneyAnswerLine: View {
    let text: String
    let symbol: String
    let tint: Color

    var body: some View {
        Label {
            Text(verbatim: text)
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(tint)
        }
        .padding(.horizontal, .spaceM)
        .padding(.vertical, .spaceS)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(.opacityFill), in: .rect(cornerRadius: .radiusM))
    }
}

private struct MoneyLensHeader: View {
    @Environment(\.open) private var open
    @Environment(\.navigationSection) private var section
    let note: String?

    var body: some View {
        AdaptiveRow(spacing: .spaceS) {
            Button {
                open(.lens, in: section)
            } label: {
                LensBadge()
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

private struct MoneyStaleSection: View {
    @Environment(MoneyModel.self) private var money

    var body: some View {
        if money.isStale, let error = money.phase.error {
            Section {
                IconRow(verbatim: error.message, symbol: error.symbol, color: .retroRust)
                Text("Showing the last data loaded.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Try Again") { Task { await money.load() } }
                    .font(.buttonLabel)
            }
        }
    }
}

private struct MoneyEmptyState: View {
    var body: some View {
        EmptyStateView(
            title: "No figures yet",
            description:
                "What a mandate costs, the office allowance and campaign money show up here, each with its official source."
        ) {
            IconRow("What a Mandate Costs", symbol: "banknote", color: .retroPlum)
            IconRow("Office allowance", symbol: "creditcard", color: .retroDenim)
            IconRow("Campaigns", symbol: "building.columns", color: .retroTeal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.plainBackground)
    }
}
