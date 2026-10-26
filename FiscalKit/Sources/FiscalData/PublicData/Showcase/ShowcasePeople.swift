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

        static let regular: [PersonCard] = [
            card("lula", "Lula", .president, "br", "PT", gender: .male),
            card("geraldo-alckmin", "Geraldo Alckmin", .vicePresident, "br", "PSB", gender: .male),
            card("damares-alves", "Damares Alves", .senator, "df", "REPUBLICANOS", gender: .female),
            card("fabiano-contarato", "Fabiano Contarato", .senator, "es", "PT", gender: .male),
            card("sergio-moro", "Sergio Moro", .senator, "pr", "UNIÃO", gender: .male),
            card("humberto-costa", "Humberto Costa", .senator, "pe", "PT", gender: .male),
            card("tereza-cristina", "Tereza Cristina", .senator, "ms", "PP", gender: .female),
            card("tabata-amaral", "Tabata Amaral", .federalDeputy, "sp", "PSB", gender: .female),
            card("kim-kataguiri", "Kim Kataguiri", .federalDeputy, "sp", "UNIÃO", gender: .male),
            card("erika-hilton", "Erika Hilton", .federalDeputy, "sp", "PSOL", gender: .female),
            card("nikolas-ferreira", "Nikolas Ferreira", .federalDeputy, "mg", "PL", gender: .male),
            card("duda-salabert", "Duda Salabert", .federalDeputy, "mg", "PDT", gender: .female),
            card(
                "marcel-van-hattem", "Marcel van Hattem", .federalDeputy, "rs", "NOVO",
                gender: .male),
            card(
                "ana-clara-moura", "Ana Clara Moura", .federalDeputy, "ba", "PSD",
                gender: .female, status: .electedAwaiting),
            card(
                "tarcisio-de-freitas", "Tarcísio de Freitas", .governor, "sp", "REPUBLICANOS",
                gender: .male),
            card("jeronimo-rodrigues", "Jerônimo Rodrigues", .governor, "ba", "PT", gender: .male),
            card("eduardo-suplicy", "Eduardo Suplicy", .stateDeputy, "sp", "PT", gender: .male),
            card("gil-diniz", "Gil Diniz", .stateDeputy, "sp", "PL", gender: .male),
            card(
                "joao-batista-lima", "João Batista Lima", .stateDeputy, "mg", "MDB",
                gender: .male, status: .onLeave),
        ]

        static let long: [PersonCard] = [
            card(
                "maria-da-conceicao-albuquerque", "Maria da Conceição Albuquerque de Vasconcellos",
                .senator, "pe", "REPUBLICANOS", gender: .female),
            card(
                "jose-roberto-figueiredo", "José Roberto Figueiredo dos Santos Magalhães Neto",
                .federalDeputy, "ba", "SOLIDARIEDADE", gender: .male),
            card(
                "ana-luiza-bittencourt", "Ana Luiza Bittencourt Cavalcanti de Oliveira",
                .federalDeputy, "rj", "CIDADANIA", gender: .female),
            card(
                "francisco-de-assis-nogueira", "Francisco de Assis Nogueira Bezerra da Silva",
                .stateDeputy, "ce", "PODEMOS", gender: .male, status: .electedAwaiting),
            card(
                "maria-aparecida-goncalves", "Maria Aparecida Gonçalves Toledo de Andrade",
                .governor, "go", "REPUBLICANOS", gender: .female),
        ]

        static func card(
            _ slug: String, _ name: String, _ office: Office, _ uf: String, _ party: String,
            gender: Gender? = nil, status: PersonStatus = .inOffice
        ) -> PersonCard {
            PersonCard(
                slug: slug, name: name, office: office, uf: uf, party: party, photo: nil,
                status: status, gender: gender)
        }

        static let longCouncil: [(office: Office, name: String, party: String)] = [
            (
                .cityCouncilor, "Maria Aparecida dos Santos Cavalcanti de Albuquerque",
                "REPUBLICANOS"
            ),
            (.cityCouncilor, "José Roberto Figueiredo dos Santos Magalhães Neto", "SOLIDARIEDADE"),
        ]

        static func longCouncilCards(in place: Place) -> [PersonCard] {
            ShowcaseRoster.cards(longCouncil, in: place, genders: [.female, .male])
        }

        static func places(cities: [Place]) -> [Place] {
            let states = states.map { Place(code: $0.uf, name: $0.name, uf: $0.uf) }
            return (states + cities).sorted {
                $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        }

        static func merged(_ curated: [PersonCard], with roster: [PersonCard]) -> [PersonCard] {
            curated + roster.filter { !covered($0, by: curated) }
        }

        static func covered(_ card: PersonCard, by people: [PersonCard]) -> Bool {
            let name = folded(card.name)
            return people.contains { other in
                guard other.slug != card.slug else { return true }
                guard other.office == card.office, other.uf == card.uf else { return false }
                let otherName = folded(other.name)
                return otherName.contains(name) || name.contains(otherName)
            }
        }

        static func folded(_ text: String) -> String {
            text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
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
