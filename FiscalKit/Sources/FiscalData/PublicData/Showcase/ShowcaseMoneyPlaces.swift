#if DEBUG
    import FiscalDomain
    import Foundation

    enum ShowcaseMoneyPlaces {
        private struct Member {
            let card: PersonCard
            let monthly: Int
            let total: Int
            let seed: Int
        }

        private static let categoryWeights = [34, 23, 14, 10, 8, 5]

        static func places(
            people: [PersonCard], now: Date, year: Int, month: Int, sources: [Source]
        ) -> MoneyPlaces? {
            var seen = Set<String>()
            let members = people.compactMap { card -> Member? in
                guard ShowcaseProfiles.isFederalLegislator(card.office),
                    card.status == .inOffice, seen.insert(card.slug).inserted
                else { return nil }
                let seed = ShowcasePeople.seed(card.slug)
                let total =
                    ShowcaseProfiles.years(seed: seed, through: year)
                    .first { $0.year == year }?.quotaCents ?? 0
                return Member(
                    card: card, monthly: total / max(month, 1), total: total, seed: seed)
            }
            guard !members.isEmpty else { return nil }
            let cost = ShowcaseMandate.cost(now: now)
            let quartiles = Dictionary(
                grouping: members, by: { $0.card.office }
            )
            .mapValues { group in quartilesOf(group.map(\.monthly)) }
            let states = Set(members.map { $0.card.uf.lowercased() }).sorted()
            let all = [
                place(
                    MoneyPlaces.country, members: members, cost: cost, quartiles: quartiles)
            ]
            let byState = states.map { uf in
                place(
                    uf, members: members.filter { $0.card.uf.lowercased() == uf }, cost: cost,
                    quartiles: quartiles)
            }
            return MoneyPlaces(year: year, places: all + byState, sources: sources)
        }

        private static func place(
            _ uf: String, members: [Member], cost: MandateCost,
            quartiles: [Office: (median: Int, p75: Int)?]
        ) -> MoneyPlaces.Place {
            let deputies = members.filter { $0.card.office == .federalDeputy }
            let senators = members.filter { $0.card.office == .senator }
            let ceiling = members.map { member in
                roleMonthly(cost, office: member.card.office, uf: member.card.uf)
            }
            .reduce(0, +)
            let total = members.map(\.total).reduce(0, +)
            let spenders = members.compactMap { member -> MoneyPlaces.Spender? in
                guard let range = quartiles[member.card.office] ?? nil,
                    member.monthly > range.p75
                else { return nil }
                let category = ShowcaseMoney.categories[
                    member.seed % ShowcaseMoney.categories.count]
                return MoneyPlaces.Spender(
                    person: member.card,
                    house: member.card.office == .senator ? "senado" : "camara",
                    monthlyCents: member.monthly, medianCents: range.median,
                    p75Cents: range.p75, band: .worse, topCategory: category,
                    topCategoryCents: member.total * 2 / 5)
            }
            .sorted { ($1.monthlyCents, $0.id) < ($0.monthlyCents, $1.id) }
            let weightSum = categoryWeights.reduce(0, +)
            let categories = zip(ShowcaseMoney.categories, categoryWeights).map { name, weight in
                MoneyOverview.CategoryAmount(category: name, cents: total * weight / weightSum)
            }
            let raised = members.map { 120_000_000 + $0.seed % 400 * 1_700_000 }.reduce(0, +)
            return MoneyPlaces.Place(
                uf: uf, deputies: deputies.count, senators: senators.count,
                ceilingMonthlyCents: ceiling > 0 ? ceiling : nil,
                quota: MoneyPlaces.Quota(
                    totalCents: total, people: members.count,
                    classified: members.filter { quartiles[$0.card.office] != nil }.count,
                    byCategory: total > 0 ? categories : [], spenders: spenders),
                campaigns: MoneyPlaces.Campaigns(
                    years: senators.isEmpty ? [2_022] : [2_018, 2_022], revenueCents: raised,
                    people: members.count))
        }

        private static func roleMonthly(_ cost: MandateCost, office: Office, uf: String) -> Int {
            let role: MandateCost.Role = office == .senator ? .senator : .federalDeputy
            return (cost.roles.first { $0.role == role }?.items ?? [])
                .compactMap { $0.cents(uf: uf) }
                .reduce(0, +)
        }

        private static func quartilesOf(_ values: [Int]) -> (median: Int, p75: Int)? {
            guard values.count >= ShowcaseBenchmarks.minimumPeers else { return nil }
            let sorted = values.sorted()
            return (percentile(sorted, 0.5), percentile(sorted, 0.75))
        }

        private static func percentile(_ sorted: [Int], _ quantile: Double) -> Int {
            let position = quantile * Double(sorted.count - 1)
            let low = Int(position.rounded(.down))
            let high = Int(position.rounded(.up))
            let part = Double(sorted[high] - sorted[low]) * (position - Double(low))
            return sorted[low] + Int(part.rounded())
        }
    }
#endif
