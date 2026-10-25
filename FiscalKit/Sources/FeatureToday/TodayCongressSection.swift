import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct TodayCongressSection: View {
    @Environment(TodayModel.self) private var today
    @Environment(FiscalNavigation.self) private var navigation: FiscalNavigation?

    var body: some View {
        TodaySection(
            "Today in Congress", source: today.agendaSource,
            action: ("See Agenda", { navigation?.selectedSection = .votes })
        ) {
            if today.houses.isEmpty {
                HStack(alignment: .top, spacing: .spaceM) {
                    ThemeTile(symbol: "calendar")
                    VStack(alignment: .leading, spacing: .space2XS) {
                        Text("No agenda published today").font(.headline)
                        Text(
                            "Sessions and the bills up for a vote show up here once the houses publish them."
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.spaceL)
                .todayCard()
                .accessibilityElement(children: .combine)
            } else {
                ForEach(today.houses) { house in
                    HouseCard(house: house)
                }
            }
        }
    }
}

private struct HouseCard: View {
    let house: TodayModel.HouseAgenda

    var body: some View {
        let shown = house.items.prefix(TodayModel.agendaLimit)
        VStack(alignment: .leading, spacing: 0) {
            HouseHeader(day: house.day)
                .padding(.spaceL)
            ForEach(shown) { item in
                Divider().padding(.leading, .spaceL)
                AgendaRow(item: item)
            }
            if house.items.count > shown.count {
                Divider().padding(.leading, .spaceL)
                Text(verbatim: TodayText.moreOnAgenda(house.items.count - shown.count))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.spaceL)
            }
        }
        .todayCard()
    }
}

private struct HouseHeader: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let day: Agenda.HouseDay

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceXS) {
            AdaptiveStack(alignment: .center, spacing: .spaceS) {
                Label {
                    Text(verbatim: day.house.title)
                } icon: {
                    Image(systemName: "building.columns")
                }
                .font(.headline)
                Spacer(minLength: 0)
                if day.inSession {
                    Label("In session", systemImage: "dot.radiowaves.left.and.right")
                        .symbolEffect(.pulse, isActive: !reduceMotion)
                        .font(.chipLabel)
                        .foregroundStyle(Color.positive)
                        .padding(.horizontal, .spaceS)
                        .padding(.vertical, .space2XS)
                        .background(Color.positive.opacity(.opacityTint), in: .capsule)
                } else {
                    Label("No session now", systemImage: "moon.zzz")
                        .font(.chipLabel)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, .spaceS)
                        .padding(.vertical, .space2XS)
                        .background(.subtleFill, in: .capsule)
                }
            }
            if !day.inSession {
                Text(verbatim: TodayText.nextSession(day.nextSession))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct AgendaRow: View {
    let item: LensOrdered<AgendaItem>

    var body: some View {
        let agenda = item.value
        VStack(alignment: .leading, spacing: .space2XS) {
            AdaptiveStack(alignment: .firstTextBaseline, spacing: .spaceS) {
                Text(verbatim: agenda.proposition)
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                if let status = agenda.status {
                    Text(verbatim: status)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            Text(verbatim: agenda.summary)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: .spaceM) {
                ForEach(agenda.themes.prefix(2), id: \.self) { ThemeTag(theme: $0) }
                if item.isLensPick { LensPickMark() }
            }
            .padding(.top, .space2XS)
        }
        .padding(.horizontal, .spaceL)
        .padding(.vertical, .spaceM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
