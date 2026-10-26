#if DEBUG
    import FiscalDomain
    import Foundation

    enum ShowcaseMandate {
        private static let guide =
            "https://www2.camara.leg.br/comunicacao/assessoria-de-imprensa/guia-para-jornalistas"

        static let deputyQuota: [String: Int] = [
            "ac": 5_735_987, "al": 5_316_436, "am": 5_615_146, "ap": 5_592_926, "ba": 5_096_529,
            "ce": 5_487_934, "df": 4_161_255, "es": 4_916_015, "go": 4_697_973, "ma": 5_453_799,
            "mg": 4_764_591, "ms": 5_270_793, "mt": 5_143_983, "pa": 5_462_417, "pb": 5_440_248,
            "pe": 5_399_781, "pi": 5_319_584, "pr": 5_080_719, "rj": 4_726_741, "rn": 5_519_809,
            "ro": 5_626_790, "rr": 5_847_470, "rs": 5_308_678, "sc": 5_195_142, "se": 5_224_886,
            "sp": 4_872_746, "to": 5_152_580,
        ]

        private static var salary: MandateCost.Item {
            MandateCost.Item(
                kind: .salary, monthlyCents: 4_636_619, byState: nil,
                act: MandateCost.Act(
                    name: "Decreto Legislativo nº 172/2022",
                    url: URL(
                        string:
                            "https://www2.camara.leg.br/legin/fed/decleg/2022/decretolegislativo-172-21-dezembro-2022-793529-publicacaooriginal-166604-pl.html"
                    ),
                    since: CalendarDay(year: 2_025, month: 2, day: 1)))
        }

        private static var deputy: MandateCost.RoleCost {
            MandateCost.RoleCost(
                role: .federalDeputy,
                items: [
                    salary,
                    MandateCost.Item(
                        kind: .quota, monthlyCents: nil,
                        byState: deputyQuota.keys.sorted().map {
                            MandateCost.StateAmount(uf: $0, monthlyCents: deputyQuota[$0] ?? 0)
                        },
                        act: MandateCost.Act(
                            name: "Ato da Mesa nº 43/2009, valores em vigor",
                            url: URL(string: guide + "/cota-parlamentar"), since: nil)),
                    MandateCost.Item(
                        kind: .staff, monthlyCents: 16_580_607, byState: nil,
                        act: MandateCost.Act(
                            name: "Ato da Mesa nº 243/2026",
                            url: URL(
                                string:
                                    "https://www2.camara.leg.br/legin/int/atomes/2026/atodamesa-243-20-fevereiro-2026-798719-norma-cd-mesa.html"
                            ),
                            since: CalendarDay(year: 2_026, month: 2, day: 20))),
                    MandateCost.Item(
                        kind: .housing, monthlyCents: 425_300, byState: nil,
                        act: MandateCost.Act(
                            name: "Ato da Mesa nº 3/2015",
                            url: URL(string: guide + "/auxilio-moradia-e-apartamento-funcional"),
                            since: nil)),
                ],
                unpublished: [])
        }

        static func cost(now: Date) -> MandateCost {
            let updated = now.addingTimeInterval(-3 * 3_600)
            let roles =
                [deputy]
                + [
                    MandateCost.RoleCost(
                        role: .senator, items: [salary], unpublished: [.quota, .staff, .housing])
                ]
                + [MandateCost.Role.president, .vicePresident, .minister].map {
                    MandateCost.RoleCost(role: $0, items: [salary], unpublished: [])
                }
            return MandateCost(
                checkedAt: CalendarDay(year: 2_026, month: 10, day: 25) ?? CalendarDay(now),
                roles: roles,
                minimumWage: MandateCost.Reference(
                    monthlyCents: 162_100, period: nil,
                    act: MandateCost.Act(
                        name: "Decreto nº 12.797/2025",
                        url: URL(
                            string:
                                "https://www.planalto.gov.br/ccivil_03/_ato2023-2026/2025/decreto/D12797.htm"
                        ),
                        since: CalendarDay(year: 2_026, month: 1, day: 1))),
                laborIncome: MandateCost.Reference(
                    monthlyCents: 373_800, period: "2º trimestre 2026",
                    act: MandateCost.Act(
                        name:
                            "PNAD Contínua, rendimento médio mensal real habitual de todos os trabalhos",
                        url: URL(string: "https://sidra.ibge.gov.br/tabela/5436"), since: nil)),
                sources: [
                    Source(
                        id: "legislacao", name: "Decreto Legislativo nº 172/2022",
                        url: URL(
                            string:
                                "https://www2.camara.leg.br/legin/fed/decleg/2022/decretolegislativo-172-21-dezembro-2022-793529-publicacaooriginal-166604-pl.html"
                        ), updatedAt: updated),
                    Source(
                        id: "camara-guia", name: "Câmara dos Deputados, Guia para jornalistas",
                        url: URL(string: guide), updatedAt: updated),
                    Source(
                        id: "planalto", name: "Presidência da República, Planalto",
                        url: URL(
                            string:
                                "https://www.planalto.gov.br/ccivil_03/_ato2023-2026/2025/decreto/D12797.htm"
                        ), updatedAt: updated),
                    Source(
                        id: "sidra-rendimento",
                        name: "IBGE, PNAD Contínua trimestral (tabela 5436)",
                        url: URL(string: "https://sidra.ibge.gov.br/tabela/5436"),
                        updatedAt: updated),
                ])
        }
    }
#endif
