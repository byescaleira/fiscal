#if DEBUG
    import FiscalDomain
    import Foundation

    enum ShowcaseChecks {
        private static let publisher = "Projeto Comprova"
        private static let license = "CC BY-ND 4.0"
        private static let licenseLink = "https://creativecommons.org/licenses/by-nd/4.0/deed.pt-br"
        private static let base = "https://projetocomprova.com.br/publica%C3%A7%C3%B5es/"

        private struct Entry {
            let id: String
            let date: String
            let verdict: String?
            let title: String
            let path: String
        }

        private static let entries: [String: [Entry]] = [
            "lula": [
                Entry(
                    id: "comprova-20389", date: "2026-09-30", verdict: "Falso",
                    title:
                        "Vídeo de Lula no Paraguai é usado fora de contexto para sugerir constrangimento na ONU",
                    path:
                        "video-de-lula-no-paraguai-e-usado-fora-de-contexto-para-sugerir-constrangimento-na-onu"
                ),
                Entry(
                    id: "comprova-20296", date: "2026-09-04", verdict: "Contextualizando",
                    title:
                        "Lula não menosprezou garis durante evento em BH; discurso foi tirado de contexto",
                    path:
                        "lula-nao-menosprezou-garis-durante-evento-em-bh-discurso-foi-tirado-de-contexto"
                ),
                Entry(
                    id: "comprova-20025", date: "2025-11-19", verdict: nil,
                    title:
                        "Vídeo de estudante atacando Lula e Alexandre de Moraes usa imagens geradas por IA",
                    path:
                        "video-de-estudante-atacando-lula-e-alexandre-de-moraes-usa-imagens-geradas-por-ia"
                ),
                Entry(
                    id: "comprova-15080", date: "2022-12-07", verdict: "Comprovado",
                    title:
                        "Vídeo de protesto em frente ao hotel em que Lula se hospedou em Brasília é verdadeiro",
                    path:
                        "video-de-protesto-em-frente-ao-hotel-em-que-lula-se-hospedou-em-brasilia-e-verdadeiro"
                ),
            ],
            "nikolas-ferreira": [
                Entry(
                    id: "comprova-19351", date: "2025-05-20", verdict: "Falso",
                    title:
                        "Vídeo exibe história fictícia de que papa Leão XIV teria elogiado deputado brasileiro",
                    path:
                        "video-exibe-historia-ficticia-de-que-papa-leao-xiv-teria-elogiado-deputado-brasileiro"
                ),
                Entry(
                    id: "comprova-14704", date: "2022-10-28", verdict: "Enganoso",
                    title:
                        "Deputado eleito repete alegações já desmentidas para tentar ligar Lula a narcotráfico e FARC",
                    path:
                        "deputado-eleito-repete-alegacoes-ja-desmentidas-para-tentar-ligar-lula-a-narcotrafico-e-farc"
                ),
            ],
            "tabata-amaral": [
                Entry(
                    id: "comprova-18252", date: "2024-09-13", verdict: "Falso",
                    title:
                        "Tabata Amaral é alvo de campanha de desinformação que a compara a criadora de conteúdo adulto",
                    path:
                        "tabata-amaral-e-alvo-de-campanha-de-desinformacao-que-a-compara-a-criadora-de-conteudo-adulto"
                )
            ],
        ]

        static func list(for slug: String, now: Date) -> FactCheckList? {
            guard let entries = entries[slug], let licenseUrl = URL(string: licenseLink) else {
                return nil
            }
            let items = entries.compactMap { entry -> FactCheck? in
                guard let day = CalendarDay(entry.date),
                    let url = URL(string: base + entry.path + "/")
                else { return nil }
                return FactCheck(
                    id: entry.id, title: entry.title, verdict: entry.verdict, date: day, url: url,
                    publisher: publisher, license: license, licenseUrl: licenseUrl)
            }
            guard !items.isEmpty else { return nil }
            let source = Source(
                id: "comprova", name: publisher, url: URL(string: "https://projetocomprova.com.br"),
                updatedAt: now.addingTimeInterval(-3 * 3_600))
            return FactCheckList(items: items, sources: [source])
        }
    }
#endif
