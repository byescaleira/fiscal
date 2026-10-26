#if DEBUG
    import FiscalDomain
    import Foundation

    enum ShowcaseWeight {
        private static let reach: [Theme: Double] = [
            .health: 1, .economy: 1, .taxes: 1, .security: 1, .consumer: 1, .environment: 1,
            .politics: 1, .education: 0.7, .social: 0.7, .transport: 0.7, .city: 0.7,
            .women: 0.7, .rights: 0.7, .technology: 0.7, .countryside: 0.4, .culture: 0.4,
            .tributes: 0.1,
        ]

        private static let testSignals = WeightSignals(
            news: nil, newsPerson: nil, wiki: nil, wikiTheme: nil, bluesky: nil, isTest: true)

        private static func kindValue(_ proposition: String) -> Double {
            switch proposition.split(separator: " ").first.map(String.init) ?? "" {
            case "PEC": 1
            case "PLP": 0.85
            case "MPV": 0.8
            case "PL", "PLS", "PLC": 0.7
            case "PDL": 0.45
            default: 0.2
            }
        }

        private static func stageValue(_ stage: String) -> Double {
            switch stage {
            case "enacted": 1
            case "plenaryApproved": 0.75
            case "plenaryRejected": 0.6
            case "committeeApproved": 0.5
            default: 0.25
            }
        }

        private static func impact(proposition: String, stage: String, themes: [Theme]) -> Int {
            let theme = themes.compactMap { reach[$0] }.max() ?? 0.5
            let value =
                0.35 * kindValue(proposition) + 0.20 + 0.25 * stageValue(stage) + 0.20 * theme
            return Int((value * 100).rounded())
        }

        private static func weight(impact: Int) -> Int { impact }

        static func actions(
            for card: PersonCard, now: Date, longText: Bool, calendar: Calendar
        ) -> ActionList {
            let year = calendar.component(.year, from: now)
            let votes = ShowcaseVotes.personVotes(for: card, now: now, longText: longText).items
                .map { vote in
                    let stage = vote.approved == false ? "plenaryRejected" : "plenaryApproved"
                    let impact = impact(
                        proposition: vote.proposition, stage: stage, themes: vote.themes)
                    return ActionItem(
                        id: "vote-\(vote.voteId)", kind: .vote, title: vote.summary,
                        proposition: vote.proposition, date: vote.date, url: nil,
                        ref: vote.voteId, ballot: vote.vote, stage: stage, themes: vote.themes,
                        weight: weight(impact: impact), repercussion: nil, impact: impact,
                        signals: testSignals)
                }
            let proposals = ShowcaseVotes.proposals(for: card, year: year).items.enumerated()
                .map { index, proposal in
                    let impact = impact(
                        proposition: proposal.reference, stage: "presented",
                        themes: proposal.themes)
                    return ActionItem(
                        id: proposal.id, kind: .proposal, title: proposal.summary,
                        proposition: proposal.reference,
                        date: CalendarDay(now.addingTimeInterval(-Double(index * 9 + 4) * 86_400)),
                        url: proposal.url, ref: nil, ballot: nil, stage: "presented",
                        themes: proposal.themes, weight: weight(impact: impact),
                        repercussion: nil, impact: impact, signals: testSignals)
                }
            let items = (votes + proposals).sorted {
                ($0.weight, $0.date) > ($1.weight, $1.date)
            }
            return ActionList(items: items, sources: ShowcaseMoney.sources(now: now))
        }

        static func highlights(now: Date, longText: Bool, sources: [Source]) -> HighlightList {
            let items = ShowcaseVotes.recent(now: now, longText: longText).map { vote in
                let stage = vote.approved == false ? "plenaryRejected" : "plenaryApproved"
                let impact = impact(
                    proposition: vote.proposition, stage: stage, themes: vote.themes)
                let house = vote.house == .camara ? "Câmara" : "Senado"
                return Highlight(
                    id: "vote-\(vote.id)", kind: .vote, title: vote.summary,
                    subtitle: [house, vote.proposition, vote.result].compactMap(\.self)
                        .joined(separator: " · "),
                    weight: weight(impact: impact), repercussion: nil, impact: impact,
                    route: vote.id, person: nil, proposition: vote.proposition, date: vote.date,
                    url: nil, signals: testSignals)
            }
            .sorted { ($0.weight, $0.date) > ($1.weight, $1.date) }
            return HighlightList(
                generatedAt: now.addingTimeInterval(-3_600), items: Array(items.prefix(4)),
                method: method(sources: sources), sources: sources)
        }

        static func method(sources: [Source]) -> WeightMethod {
            WeightMethod(
                version: 1,
                summary:
                    "O peso ordena o que cada político faz, de 0 a 100. Ele soma quanto se fala do assunto (repercussão) e o alcance da medida (impacto). A mesma regra vale para todos os políticos e temas, e o peso nunca diz se a medida é boa ou ruim.",
                formula:
                    "Peso = 50% repercussão + 50% impacto; sem nenhum sinal de repercussão medido, peso = impacto",
                repercussion:
                    "Contagens dos últimos 30 dias em fontes abertas, em escala logarítmica até um teto.",
                impact:
                    "Regra fixa: tipo da proposição, abrangência, estágio e o alcance do tema em pessoas atingidas.",
                parts: [
                    .init(key: "news", label: "Notícias sobre a proposição", share: 0.4),
                    .init(key: "newsPerson", label: "Notícias que citam o político", share: 0.2),
                    .init(
                        key: "wiki", label: "Visitas ao artigo do político na Wikipédia",
                        share: 0.25),
                    .init(
                        key: "wikiTheme", label: "Visitas ao artigo do tema na Wikipédia",
                        share: 0.15),
                    .init(key: "bluesky", label: "Posts no Bluesky", share: 0),
                ],
                signals: [
                    .init(
                        id: "gdelt", name: "GDELT DOC 2.0",
                        url: URL(string: "https://api.gdeltproject.org/api/v2/doc/doc"),
                        measures: "Notícias em português que citam a proposição ou o político",
                        window: "30 dias", status: "measured", note: nil),
                    .init(
                        id: "wikipedia", name: "Wikimedia Pageviews",
                        url: URL(string: "https://wikimedia.org/api/rest_v1/metrics/pageviews/"),
                        measures: "Visitas ao artigo do político e do tema na Wikipédia",
                        window: "30 dias", status: "measured", note: nil),
                    .init(
                        id: "bluesky", name: "Bluesky",
                        url: URL(string: "https://public.api.bsky.app"),
                        measures: "Posts que citam a proposição", window: "30 dias",
                        status: "notMeasured",
                        note: "A busca pública responde 403 sem autenticação."),
                ],
                impactParts: [
                    .init(key: "kind", label: "Tipo da proposição", share: 0.35),
                    .init(key: "scope", label: "Abrangência", share: 0.2),
                    .init(key: "stage", label: "Estágio", share: 0.25),
                    .init(key: "theme", label: "Alcance do tema", share: 0.2),
                ],
                kinds: [
                    .init(key: "PEC", label: "Proposta de emenda à Constituição", value: 1),
                    .init(key: "PLP", label: "Projeto de lei complementar", value: 0.85),
                    .init(key: "PL", label: "Projeto de lei", value: 0.7),
                    .init(key: "PDL", label: "Projeto de decreto legislativo", value: 0.45),
                    .init(key: "REQ", label: "Requerimento ou indicação", value: 0.1),
                ],
                scopes: [
                    .init(key: "national", label: "Nacional", value: 1),
                    .init(key: "state", label: "Estadual", value: 0.5),
                    .init(key: "municipal", label: "Municipal", value: 0.2),
                ],
                stages: [
                    .init(key: "presented", label: "Apresentado", value: 0.25),
                    .init(key: "committeeApproved", label: "Aprovado em comissão", value: 0.5),
                    .init(
                        key: "plenaryRejected", label: "Votado e rejeitado em plenário", value: 0.6),
                    .init(key: "plenaryApproved", label: "Aprovado em plenário", value: 0.75),
                    .init(key: "enacted", label: "Virou lei", value: 1),
                ],
                themes: Theme.allCases.map {
                    .init(key: $0.rawValue, reach: reach[$0] ?? 0.5, reason: $0.title)
                },
                decay: .init(
                    halfLifeDays: 14, windowDays: 90,
                    text:
                        "No Destaque do momento, o peso cai pela metade a cada 14 dias desde a data do fato."
                ),
                rules: [
                    "A mesma regra vale para todos os políticos, partidos e temas.",
                    "O peso ordena e destaca; ele não qualifica a medida nem o político.",
                ],
                limits: ["Neste modo de teste, a repercussão não é medida."],
                sources: sources, alert: .standard,
                renormalization:
                    "Sinal ausente não conta como zero. A repercussão é a média ponderada só dos sinais medidos nesta carga; sem nenhum sinal medido, o peso é só o impacto, e o app avisa."
            )
        }
    }
#endif
