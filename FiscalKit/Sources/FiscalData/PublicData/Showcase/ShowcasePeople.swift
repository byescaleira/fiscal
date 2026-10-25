#if DEBUG
    import FiscalDomain
    import Foundation

    enum ShowcasePeople {
        static let states: [(uf: String, name: String)] = [
            ("ac", "Acre"), ("al", "Alagoas"), ("am", "Amazonas"), ("ap", "Amapá"),
            ("ba", "Bahia"), ("ce", "Ceará"), ("df", "Distrito Federal"),
            ("es", "Espírito Santo"), ("go", "Goiás"), ("ma", "Maranhão"),
            ("mg", "Minas Gerais"), ("ms", "Mato Grosso do Sul"), ("mt", "Mato Grosso"),
            ("pa", "Pará"), ("pb", "Paraíba"), ("pe", "Pernambuco"), ("pi", "Piauí"),
            ("pr", "Paraná"), ("rj", "Rio de Janeiro"), ("rn", "Rio Grande do Norte"),
            ("ro", "Rondônia"), ("rr", "Roraima"), ("rs", "Rio Grande do Sul"),
            ("sc", "Santa Catarina"), ("se", "Sergipe"), ("sp", "São Paulo"),
            ("to", "Tocantins"),
        ]

        static let cities: [Place] = [
            Place(code: "1200401", name: "Rio Branco", uf: "ac"),
            Place(code: "2611606", name: "Recife", uf: "pe"),
            Place(code: "2927408", name: "Salvador", uf: "ba"),
            Place(code: "3106200", name: "Belo Horizonte", uf: "mg"),
            Place(code: "3304557", name: "Rio de Janeiro", uf: "rj"),
            Place(code: "3550308", name: "São Paulo", uf: "sp"),
            Place(code: "4106902", name: "Curitiba", uf: "pr"),
            Place(code: "4314902", name: "Porto Alegre", uf: "rs"),
            Place(code: "5300108", name: "Brasília", uf: "df"),
        ]

        static let regular: [PersonCard] = [
            card("lula", "Lula", .president, "br", "PT"),
            card("geraldo-alckmin", "Geraldo Alckmin", .vicePresident, "br", "PSB"),
            card("damares-alves", "Damares Alves", .senator, "df", "REPUBLICANOS"),
            card("fabiano-contarato", "Fabiano Contarato", .senator, "es", "PT"),
            card("sergio-moro", "Sergio Moro", .senator, "pr", "UNIÃO"),
            card("humberto-costa", "Humberto Costa", .senator, "pe", "PT"),
            card("tereza-cristina", "Tereza Cristina", .senator, "ms", "PP"),
            card("tabata-amaral", "Tabata Amaral", .federalDeputy, "sp", "PSB"),
            card("kim-kataguiri", "Kim Kataguiri", .federalDeputy, "sp", "UNIÃO"),
            card("erika-hilton", "Erika Hilton", .federalDeputy, "sp", "PSOL"),
            card("nikolas-ferreira", "Nikolas Ferreira", .federalDeputy, "mg", "PL"),
            card("duda-salabert", "Duda Salabert", .federalDeputy, "mg", "PDT"),
            card("marcel-van-hattem", "Marcel van Hattem", .federalDeputy, "rs", "NOVO"),
            card(
                "ana-clara-moura", "Ana Clara Moura", .federalDeputy, "ba", "PSD",
                status: .electedAwaiting),
            card("tarcisio-de-freitas", "Tarcísio de Freitas", .governor, "sp", "REPUBLICANOS"),
            card("jeronimo-rodrigues", "Jerônimo Rodrigues", .governor, "ba", "PT"),
            card("eduardo-suplicy", "Eduardo Suplicy", .stateDeputy, "sp", "PT"),
            card("gil-diniz", "Gil Diniz", .stateDeputy, "sp", "PL"),
            card(
                "joao-batista-lima", "João Batista Lima", .stateDeputy, "mg", "MDB",
                status: .onLeave),
        ]

        static let long: [PersonCard] = [
            card(
                "maria-da-conceicao-albuquerque", "Maria da Conceição Albuquerque de Vasconcellos",
                .senator, "pe", "REPUBLICANOS"),
            card(
                "jose-roberto-figueiredo", "José Roberto Figueiredo dos Santos Magalhães Neto",
                .federalDeputy, "ba", "SOLIDARIEDADE"),
            card(
                "ana-luiza-bittencourt", "Ana Luiza Bittencourt Cavalcanti de Oliveira",
                .federalDeputy, "rj", "CIDADANIA"),
            card(
                "francisco-de-assis-nogueira", "Francisco de Assis Nogueira Bezerra da Silva",
                .stateDeputy, "ce", "PODEMOS", status: .electedAwaiting),
            card(
                "maria-aparecida-goncalves", "Maria Aparecida Gonçalves Toledo de Andrade",
                .governor, "go", "REPUBLICANOS"),
        ]

        static func card(
            _ slug: String, _ name: String, _ office: Office, _ uf: String, _ party: String,
            status: PersonStatus = .inOffice
        ) -> PersonCard {
            PersonCard(
                slug: slug, name: name, office: office, uf: uf, party: party, photo: nil,
                status: status)
        }

        static func places() -> [Place] {
            let states = states.map { Place(code: $0.uf, name: $0.name, uf: $0.uf) }
            return (states + cities).sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        }

        static func stateName(_ uf: String) -> String {
            uf == "br" ? "Brasil" : states.first { $0.uf == uf }?.name ?? uf.uppercased()
        }

        static func representatives(
            uf: String, people: [PersonCard], sources: [Source]
        ) -> PlaceRepresentatives {
            let uf = uf.lowercased()
            let groups: [RepresentativeGroup] = [
                group(.country, .president, "Presidente", people, uf: "br"),
                group(.country, .vicePresident, "Vice-presidente", people, uf: "br"),
                group(.state, .senator, "Senadores", people, uf: uf),
                group(.state, .federalDeputy, "Deputados federais", people, uf: uf),
                group(.state, .governor, "Governador", people, uf: uf),
                group(.state, .viceGovernor, "Vice-governador", people, uf: uf),
                group(.state, .stateDeputy, "Deputados estaduais", people, uf: uf),
            ]
            return PlaceRepresentatives(
                uf: uf, name: stateName(uf), groups: groups.filter { !$0.people.isEmpty },
                sources: sources)
        }

        private static func group(
            _ level: RepresentativeGroup.Level, _ office: Office, _ title: String,
            _ people: [PersonCard], uf: String
        ) -> RepresentativeGroup {
            RepresentativeGroup(
                level: level, office: office, title: title,
                people: people.filter { $0.office == office && $0.uf == uf })
        }

        static func seed(_ slug: String) -> Int {
            var hash: UInt64 = 1_469_598_103_934_665_603
            for byte in slug.utf8 {
                hash ^= UInt64(byte)
                hash = hash &* 1_099_511_628_211
            }
            return Int(hash % 1_000)
        }
    }
#endif
