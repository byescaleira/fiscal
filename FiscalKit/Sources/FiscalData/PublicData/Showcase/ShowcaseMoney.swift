#if DEBUG
    import FiscalDomain
    import Foundation

    enum ShowcaseMoney {
        static let categories = [
            "Divulgação da atividade parlamentar", "Passagens aéreas", "Manutenção de escritório",
            "Combustíveis e lubrificantes", "Locação de veículos", "Telefonia",
        ]

        static func sources(now: Date) -> [Source] {
            let updated = now.addingTimeInterval(-3 * 3_600)
            return [
                Source(
                    id: "camara", name: "Câmara dos Deputados",
                    url: URL(string: "https://dadosabertos.camara.leg.br"), updatedAt: updated),
                Source(
                    id: "senado", name: "Senado Federal",
                    url: URL(string: "https://legis.senado.leg.br/dadosabertos"), updatedAt: updated
                ),
                Source(
                    id: "tse", name: "Tribunal Superior Eleitoral",
                    url: URL(string: "https://dadosabertos.tse.jus.br"), updatedAt: updated),
            ]
        }

        static func expenses(for card: PersonCard, year: Int) -> ExpenseList {
            let seed = ShowcasePeople.seed(card.slug)
            let items = (0..<8).map { index in
                Expense(
                    id: "\(card.slug)-\(year)-\(index)", year: year, month: 1 + (seed + index) % 9,
                    category: categories[(seed + index) % categories.count],
                    supplier: suppliers[(seed + index * 3) % suppliers.count], document: nil,
                    cents: 45_000 + ((seed * (index + 3)) % 900) * 1_250, url: nil)
            }
            let byMonth = Dictionary(grouping: items, by: \.month)
                .map {
                    ExpenseList.MonthTotal(month: $0.key, cents: $0.value.map(\.cents).reduce(0, +))
                }
                .sorted { $0.month < $1.month }
            let byCategory = Dictionary(grouping: items, by: \.category)
                .map {
                    ExpenseList.CategoryTotal(
                        category: $0.key, cents: $0.value.map(\.cents).reduce(0, +),
                        count: $0.value.count)
                }
                .sorted { $0.cents > $1.cents }
            return ExpenseList(
                items: items, totalCents: items.map(\.cents).reduce(0, +), byMonth: byMonth,
                byCategory: byCategory)
        }

        static func overview(year: Int, empty: Bool, sources: [Source]) -> MoneyOverview {
            guard !empty else {
                return MoneyOverview(
                    year: year,
                    quota: MoneyOverview.Quota(
                        federalDeputiesCents: 0, senatorsCents: 0, byCategory: []),
                    salaries: [],
                    campaigns: MoneyOverview.Campaigns(
                        year: 2_022, revenueCents: 0, expenseCents: 0, byOrigin: []),
                    revenue: nil, sources: sources)
            }
            return MoneyOverview(
                year: year,
                quota: MoneyOverview.Quota(
                    federalDeputiesCents: 19_840_000_000, senatorsCents: 2_715_000_000,
                    byCategory: zip(
                        categories,
                        [
                            7_210_000_000, 4_980_000_000, 2_930_000_000, 2_140_000_000,
                            1_650_000_000, 930_000_000,
                        ]
                    )
                    .map { MoneyOverview.CategoryAmount(category: $0, cents: $1) }),
                salaries: [
                    .init(
                        office: .president, monthlyCents: 4_636_619,
                        law: "Decreto Legislativo 173/2022"),
                    .init(
                        office: .vicePresident, monthlyCents: 4_636_619,
                        law: "Decreto Legislativo 173/2022"),
                    .init(
                        office: .senator, monthlyCents: 4_636_619,
                        law: "Decreto Legislativo 172/2022"),
                    .init(
                        office: .federalDeputy, monthlyCents: 4_636_619,
                        law: "Decreto Legislativo 172/2022"),
                ],
                campaigns: MoneyOverview.Campaigns(
                    year: 2_022, revenueCents: 612_000_000_000, expenseCents: 598_000_000_000,
                    byOrigin: [
                        .init(
                            origin: "Fundo Especial de Financiamento de Campanha",
                            cents: 493_000_000_000),
                        .init(origin: "Fundo Partidário", cents: 61_000_000_000),
                        .init(origin: "Pessoas físicas", cents: 42_000_000_000),
                        .init(origin: "Recursos próprios", cents: 16_000_000_000),
                    ]),
                revenue: MoneyOverview.Revenue(
                    year: year - 1, totalCents: 287_400_000_000_000,
                    byState: [
                        .init(uf: "sp", cents: 118_300_000_000_000),
                        .init(uf: "rj", cents: 42_100_000_000_000),
                        .init(uf: "df", cents: 25_600_000_000_000),
                        .init(uf: "mg", cents: 19_800_000_000_000),
                    ]),
                sources: sources)
        }

        static func today(now: Date, votes: [VoteSummary], sources: [Source]) -> TodayDigest {
            let events = votes.prefix(2).map { vote in
                TodayDigest.Event(
                    kind: .vote,
                    title:
                        "\(vote.house == .camara ? "Câmara" : "Senado") votou o \(vote.proposition)",
                    summary: vote.plainSummary ?? vote.summary, themes: vote.themes, ref: vote.id)
            }
            let others = [
                TodayDigest.Event(
                    kind: .session, title: "Senado tem sessão deliberativa na terça",
                    summary: "Na pauta, a poupança para estudantes de cursos técnicos.",
                    themes: [.education], ref: nil),
                TodayDigest.Event(
                    kind: .race, title: "Apuração do segundo turno",
                    summary: "Os números chegam direto do TSE, sem projeção nem pesquisa.",
                    themes: [.politics], ref: "presidente-br"),
            ]
            return TodayDigest(
                date: CalendarDay(now), events: Array(events) + others, sources: sources)
        }

        private static let suppliers = [
            "LATAM Linhas Aéreas", "GOL Linhas Aéreas", "Azul Linhas Aéreas", "Gráfica Planalto",
            "Posto Esplanada", "Locadora Cerrado", "Papelaria Central",
        ]
    }
#endif
