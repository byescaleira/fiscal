#if DEBUG
    import FiscalDomain
    import Foundation

    enum ShowcaseProfiles {
        static let federalSalaryCents = 4_636_619

        static func profile(for card: PersonCard, year: Int, sources: [Source]) -> Profile {
            let seed = ShowcasePeople.seed(card.slug)
            let legislator = isFederalLegislator(card.office)
            return Profile(
                card: card, civilName: nil, mandate: mandate(for: card),
                birthDate: CalendarDay(
                    year: 1_960 + seed % 35, month: 1 + seed % 12, day: 1 + seed % 28),
                birthPlace: ShowcasePeople.stateName(card.uf == "br" ? "sp" : card.uf),
                education: seed.isMultiple(of: 3) ? "Superior completo" : "Pós-graduação",
                contact: legislator ? contact(for: card) : nil,
                salary: salary(for: card.office),
                numbers: numbers(for: card, seed: seed),
                history: history(for: card, seed: seed, year: year),
                sources: sources)
        }

        static func officeName(_ office: Office) -> String {
            switch office {
            case .president: "Presidente"
            case .vicePresident: "Vice-presidente"
            case .senator: "Senador"
            case .federalDeputy: "Deputado federal"
            case .governor: "Governador"
            case .viceGovernor: "Vice-governador"
            case .stateDeputy: "Deputado estadual"
            }
        }

        static func isFederalLegislator(_ office: Office) -> Bool {
            office == .senator || office == .federalDeputy
        }

        private static func mandate(for card: PersonCard) -> Profile.Mandate {
            switch card.office {
            case .president, .vicePresident:
                Profile.Mandate(
                    start: CalendarDay(year: 2_023, month: 1, day: 1),
                    end: CalendarDay(year: 2_027, month: 1, day: 5))
            case .governor, .viceGovernor:
                Profile.Mandate(
                    start: CalendarDay(year: 2_023, month: 1, day: 1),
                    end: CalendarDay(year: 2_027, month: 1, day: 6))
            case .senator:
                Profile.Mandate(
                    start: CalendarDay(year: 2_023, month: 2, day: 1),
                    end: CalendarDay(year: 2_031, month: 1, day: 31))
            case .federalDeputy, .stateDeputy:
                card.status == .electedAwaiting
                    ? Profile.Mandate(
                        start: CalendarDay(year: 2_027, month: 2, day: 1),
                        end: CalendarDay(year: 2_031, month: 1, day: 31))
                    : Profile.Mandate(
                        start: CalendarDay(year: 2_023, month: 2, day: 1),
                        end: CalendarDay(year: 2_027, month: 1, day: 31))
            }
        }

        private static func contact(for card: PersonCard) -> Profile.Contact {
            let user = card.slug.replacingOccurrences(of: "-", with: ".")
            return card.office == .senator
                ? Profile.Contact(
                    email: "sen.\(user)@senado.leg.br",
                    phone: "(61) 3303-\(4_000 + card.slug.count)",
                    office: "Senado Federal, Anexo II")
                : Profile.Contact(
                    email: "dep.\(user)@camara.leg.br",
                    phone: "(61) 3215-\(5_000 + card.slug.count)",
                    office: "Câmara dos Deputados, Anexo IV")
        }

        private static func salary(for office: Office) -> Profile.Salary? {
            switch office {
            case .senator, .federalDeputy:
                Profile.Salary(
                    monthlyCents: federalSalaryCents, law: "Decreto Legislativo 172/2022")
            case .president, .vicePresident:
                Profile.Salary(
                    monthlyCents: federalSalaryCents, law: "Decreto Legislativo 173/2022")
            case .governor, .viceGovernor, .stateDeputy:
                nil
            }
        }

        private static func numbers(for card: PersonCard, seed: Int) -> Profile.Numbers {
            guard isFederalLegislator(card.office), card.status != .electedAwaiting else {
                return Profile.Numbers(
                    attendance: nil, proposals: nil, laws: nil, speeches: nil, votes: nil,
                    quotaCents: nil, assetsCents: 80_000_000 + seed * 1_250_000,
                    campaignRevenueCents: 150_000_000 + seed * 900_000,
                    lastElectionVotes: card.office == .stateDeputy ? 40_000 + seed * 120 : nil)
            }
            let eligible = 300 + seed % 40
            return Profile.Numbers(
                attendance: Profile.Attendance(
                    present: eligible - seed % 37, eligible: eligible),
                proposals: 20 + seed % 90, laws: seed % 6, speeches: 40 + seed % 160,
                votes: 520 + seed % 80, quotaCents: 95_000_000 + seed * 210_000,
                assetsCents: 30_000_000 + seed * 2_100_000,
                campaignRevenueCents: 120_000_000 + seed * 1_700_000,
                lastElectionVotes: 90_000 + seed * 1_300)
        }

        private static func history(for card: PersonCard, seed: Int, year: Int) -> Profile.History {
            let legislator = isFederalLegislator(card.office) && card.status != .electedAwaiting
            let themes = Array(Theme.allCases.rotated(by: seed).prefix(4))
            return Profile.History(
                years: legislator ? years(seed: seed, through: year) : [],
                themes: themes.enumerated().map { index, theme in
                    Profile.ThemeCount(
                        key: theme, proposals: 12 - index * 2 + seed % 5,
                        speeches: 9 - index * 2 + seed % 4)
                },
                committees: legislator
                    ? [
                        Profile.Committee(
                            name: card.office == .senator
                                ? "Comissão de Constituição, Justiça e Cidadania"
                                : "Comissão de Constituição e Justiça e de Cidadania",
                            role: seed.isMultiple(of: 2) ? "Titular" : "Suplente",
                            start: CalendarDay(year: 2_025, month: 3, day: 12), end: nil)
                    ] : [],
                assets: [
                    Profile.AssetDeclaration(
                        year: 2_022, totalCents: 30_000_000 + seed * 2_100_000,
                        items: [
                            .init(kind: "Imóvel", cents: 20_000_000 + seed * 1_500_000),
                            .init(kind: "Aplicação financeira", cents: 10_000_000 + seed * 600_000),
                        ])
                ],
                campaigns: [
                    Profile.Campaign(
                        year: 2_022, office: officeName(card.office), result: "Eleito",
                        revenueCents: 120_000_000 + seed * 1_700_000,
                        expenseCents: 110_000_000 + seed * 1_600_000)
                ],
                timeline: [
                    Profile.Career(
                        year: 2_022, office: officeName(card.office),
                        place: ShowcasePeople.stateName(card.uf), party: card.party,
                        result: "Eleito", votes: 90_000 + seed * 1_300)
                ],
                coverage: coverage(for: card, legislator: legislator))
        }

        private static func years(seed: Int, through year: Int) -> [Profile.Year] {
            (2_023...max(2_023, year)).map { value in
                let eligible = 70 + (seed + value) % 25
                return Profile.Year(
                    year: value, present: eligible - (seed + value) % 9, eligible: eligible,
                    proposals: 4 + (seed + value) % 20, laws: (seed + value) % 2,
                    speeches: 10 + (seed + value) % 40, votes: 120 + (seed + value) % 30,
                    quotaCents: 25_000_000 + ((seed + value) % 50) * 300_000)
            }
        }

        private static func coverage(for card: PersonCard, legislator: Bool) -> [Profile.Coverage] {
            let source = card.office == .senator ? "senado" : "camara"
            let activity: Profile.Coverage.Status = legislator ? .available : .notPublished
            return ["attendance", "votes", "proposals", "speeches", "expenses"].map {
                Profile.Coverage(kind: $0, status: activity, source: legislator ? source : nil)
            } + [Profile.Coverage(kind: "assets", status: .available, source: "tse")]
        }
    }

    extension Array {
        fileprivate func rotated(by offset: Int) -> [Element] {
            guard !isEmpty else { return self }
            let shift = offset % count
            return Array(self[shift...] + self[..<shift])
        }
    }
#endif
