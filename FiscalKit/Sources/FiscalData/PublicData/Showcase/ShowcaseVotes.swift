#if DEBUG
    import FiscalDomain
    import Foundation

    enum ShowcaseVotes {
        private struct Seed {
            let house: House
            let proposition: String
            let kind: String
            let summary: String
            let plain: String
            let themes: [Theme]
            let tally: (yes: Int, no: Int, others: Int)
        }

        private static let seeds: [Seed] = [
            Seed(
                house: .camara, proposition: "PL 1873/2026", kind: "Projeto de Lei",
                summary:
                    "Altera a Lei nº 9.250, de 1995, para corrigir anualmente pela inflação a tabela do imposto de renda da pessoa física.",
                plain:
                    "Muda uma lei para corrigir todo ano a tabela do imposto de renda pela inflação.",
                themes: [.taxes, .economy], tally: (412, 61, 9)),
            Seed(
                house: .senado, proposition: "PL 2290/2026", kind: "Projeto de Lei",
                summary:
                    "Dispõe sobre a transparência no uso de inteligência artificial por órgãos públicos.",
                plain: "Cria regras para o governo avisar quando usa inteligência artificial.",
                themes: [.technology, .rights], tally: (52, 18, 3)),
            Seed(
                house: .camara, proposition: "PL 3051/2026", kind: "Projeto de Lei",
                summary:
                    "Aumenta as penas para os crimes de roubo e furto de celulares e cabos de energia.",
                plain: "Aumenta a pena para quem rouba celular ou cabos de energia.",
                themes: [.security], tally: (338, 121, 14)),
            Seed(
                house: .senado, proposition: "PEC 14/2026",
                kind: "Proposta de Emenda à Constituição",
                summary: "Altera a Constituição para fixar o piso nacional da enfermagem.",
                plain: "Muda a Constituição para garantir um salário mínimo para a enfermagem.",
                themes: [.health, .economy], tally: (61, 9, 2)),
            Seed(
                house: .camara, proposition: "PL 3388/2026", kind: "Projeto de Lei",
                summary: "Altera os prazos do licenciamento ambiental de obras de saneamento.",
                plain:
                    "Muda os prazos para liberar obras de água e esgoto que afetam o meio ambiente.",
                themes: [.environment, .city], tally: (267, 188, 22)),
            Seed(
                house: .senado, proposition: "PL 4012/2026", kind: "Projeto de Lei",
                summary:
                    "Amplia o Programa Pé-de-Meia para estudantes do ensino técnico e da educação de jovens e adultos.",
                plain:
                    "Estende a poupança para estudantes de cursos técnicos e de jovens e adultos.",
                themes: [.education, .social], tally: (58, 11, 4)),
        ]

        private struct Step {
            let id: String
            let time: String
            let short: String
            let official: String
            let nominal: Bool
            let tally: VoteSummary.Tally
        }

        private static let groupID = "camara-pl-1873-2026"

        private static let steps: [Step] = [
            Step(
                id: "camara-1873-urgencia", time: "16:31", short: "Requerimento de urgência",
                official: "Aprovado o Requerimento de Urgência (Art. 155 do RICD).", nominal: true,
                tally: VoteSummary.Tally(yes: 389, no: 54, others: 6)),
            Step(
                id: "camara-18732026", time: "17:12", short: "Texto principal",
                official: "", nominal: true,
                tally: VoteSummary.Tally(yes: nil, no: nil, others: nil)),
            Step(
                id: "camara-1873-redacao", time: "17:20", short: "Redação final",
                official: "Aprovada a Redação Final assinada pelo relator.", nominal: false,
                tally: VoteSummary.Tally(yes: nil, no: nil, others: nil)),
        ]

        private static func related(excluding id: String) -> [VoteSummary.Related] {
            steps.filter { $0.id != id }.map { step in
                VoteSummary.Related(
                    id: step.id, time: step.time, summary: step.short, nominal: step.nominal,
                    approved: true)
            }
        }

        static func recent(now: Date, longText: Bool) -> [VoteSummary] {
            seeds.enumerated().map { index, seed in
                summary(seed, index: index, now: now, longText: longText)
            }
        }

        static func sameDay(now: Date, longText: Bool) -> [VoteSummary] {
            guard let main = recent(now: now, longText: longText).first else { return [] }
            return steps.filter { $0.id != main.id }.map { step in
                VoteSummary(
                    id: step.id, house: main.house, date: main.date, time: step.time,
                    proposition: main.proposition, kind: main.kind, summary: step.official,
                    plainSummary: main.plainSummary, themes: main.themes, result: "Aprovado",
                    approved: true, nominal: step.nominal, tally: step.tally, group: groupID,
                    related: related(excluding: step.id))
            }
        }

        static func detail(
            id: String, now: Date, people: [PersonCard], sources: [Source], longText: Bool
        ) -> VoteDetail? {
            let all = recent(now: now, longText: longText) + sameDay(now: now, longText: longText)
            guard let summary = all.first(where: { $0.id == id }) else { return nil }
            guard summary.nominal else {
                return VoteDetail(
                    vote: summary, quorum: nil, guidance: [], parties: [], people: [],
                    sources: sources)
            }
            let office: Office = summary.house == .camara ? .federalDeputy : .senator
            let voters = people.filter { $0.office == office && $0.status == .inOffice }
            let ballots = ShowcaseVoteRoll.complete(
                voters.map { card in
                    VoteDetail.Ballot(
                        slug: card.slug, name: card.name, party: card.party, uf: card.uf,
                        vote: ballot(for: card.slug, voteID: id))
                }, for: summary)
            let parties = Dictionary(grouping: ballots, by: \.party).map { party, ballots in
                VoteDetail.PartyTally(
                    party: party, yes: ballots.filter { $0.vote == "Sim" }.count,
                    no: ballots.filter { $0.vote == "Não" }.count,
                    others: ballots.filter { $0.vote != "Sim" && $0.vote != "Não" }.count)
            }
            .sorted { $0.party.localizedStandardCompare($1.party) == .orderedAscending }
            let guidance =
                summary.house == .senado
                ? []
                : parties.map {
                    VoteDetail.Guidance(party: $0.party, guidance: $0.yes >= $0.no ? "Sim" : "Não")
                }
            return VoteDetail(
                vote: summary,
                quorum: summary.house == .camara
                    ? "Para passar, precisa da maioria dos votos, com pelo menos 257 de 513 presentes."
                    : "Para passar, precisa da maioria dos votos, com pelo menos 41 de 81 presentes.",
                guidance: guidance,
                parties: parties, people: ballots, sources: sources)
        }

        static func personVotes(for card: PersonCard, now: Date, longText: Bool) -> PublicList<
            PersonVote
        > {
            let house: House = card.office == .senator ? .senado : .camara
            let items = recent(now: now, longText: longText).filter { $0.house == house }.map {
                vote in
                PersonVote(
                    voteId: vote.id, date: vote.date, proposition: vote.proposition,
                    summary: vote.plainSummary ?? vote.summary,
                    vote: ballot(for: card.slug, voteID: vote.id),
                    partyGuidance: house == .senado ? nil : "Sim", approved: vote.approved,
                    themes: vote.themes)
            }
            return PublicList(items: items, total: items.count)
        }

        static func proposals(for card: PersonCard, year: Int) -> PublicList<Proposal> {
            let seed = ShowcasePeople.seed(card.slug)
            let themes = Theme.allCases
            let items = (0..<3).map { index in
                let theme = themes[(seed + index * 5) % themes.count]
                return Proposal(
                    id: "\(card.slug)-\(year)-\(index)", kind: "PL",
                    number: 1_000 + seed + index * 37,
                    year: year,
                    summary:
                        "Dispõe sobre medidas de \(theme.rawValue) e altera a legislação em vigor.",
                    plainSummary: "Propõe mudanças na área de \(theme.rawValue).",
                    canBecomeLaw: index != 2, themes: [theme], url: nil)
            }
            return PublicList(items: items, total: 9 + seed % 20)
        }

        static func speeches(for card: PersonCard, now: Date) -> PublicList<Speech> {
            let items = (0..<2).map { index in
                Speech(
                    date: CalendarDay(now.addingTimeInterval(-Double(index + 2) * 86_400)),
                    kind: index == 0 ? "Pronunciamento" : "Breves comunicações",
                    summary: "Comenta a pauta da semana no Plenário e as votações previstas.",
                    url: nil)
            }
            return PublicList(items: items, total: 30 + ShowcasePeople.seed(card.slug) % 40)
        }

        static func agenda(now: Date, empty: Bool) -> Agenda {
            let next = now.addingTimeInterval(2 * 86_400)
            let houses: [Agenda.HouseDay] =
                empty
                ? []
                : [
                    Agenda.HouseDay(
                        house: .camara, inSession: false, nextSession: next,
                        items: [
                            AgendaItem(
                                proposition: "PL 3051/2026",
                                summary:
                                    "Aumenta a pena para quem rouba celular ou cabos de energia.",
                                status: "Pronto para a pauta", themes: [.security], url: nil),
                            AgendaItem(
                                proposition: "PL 4407/2026",
                                summary: "Cria um cadastro nacional de doadores de medula óssea.",
                                status: "Aguardando parecer", themes: [.health], url: nil),
                        ]),
                    Agenda.HouseDay(
                        house: .senado, inSession: false,
                        nextSession: next.addingTimeInterval(86_400),
                        items: [
                            AgendaItem(
                                proposition: "PL 4012/2026",
                                summary: "Estende a poupança para estudantes de cursos técnicos.",
                                status: "Em votação", themes: [.education, .social], url: nil)
                        ]),
                ]
            return Agenda(date: CalendarDay(now), houses: houses)
        }

        static func ballot(for slug: String, voteID: String) -> String {
            switch (ShowcasePeople.seed(slug) + voteID.count * 7) % 10 {
            case 0: "Abstenção"
            case 1: "Ausente"
            case 2, 3, 4: "Não"
            default: "Sim"
            }
        }

        private static func summary(_ seed: Seed, index: Int, now: Date, longText: Bool)
            -> VoteSummary
        {
            let date = now.addingTimeInterval(-Double(index / 2 + 1) * 86_400)
            let number = seed.proposition.filter(\.isNumber)
            let suffix =
                longText
                ? " Inclui ainda dispositivos sobre fiscalização, transparência, prazos de transição e revisão periódica das regras pelo Poder Executivo."
                : ""
            let approved = seed.tally.yes > seed.tally.no
            return VoteSummary(
                id: "\(seed.house.rawValue)-\(number)", house: seed.house, date: CalendarDay(date),
                time: "\(17 + index % 4):\(index.isMultiple(of: 2) ? "12" : "48")",
                proposition: seed.proposition, kind: seed.kind, summary: seed.summary + suffix,
                plainSummary: seed.plain + suffix, themes: seed.themes,
                result: approved ? "Aprovado" : "Rejeitado", approved: approved, nominal: true,
                tally: VoteSummary.Tally(
                    yes: seed.tally.yes, no: seed.tally.no, others: seed.tally.others),
                group: index == 0 ? groupID : nil,
                related: index == 0 ? related(excluding: "\(seed.house.rawValue)-\(number)") : [])
        }
    }
#endif
