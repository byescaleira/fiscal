#if DEBUG
    import FiscalDomain
    import Foundation

    enum ShowcaseCities {
        typealias Official = (office: Office, name: String, party: String)

        static let brasiliaNote =
            "Brasília não tem prefeito nem vereadores: o Distrito Federal é governado pelo governador, e as leis locais saem da Câmara Legislativa."

        static let all: [ShowcaseRoster.City] = [
            city(
                "1200401", "Rio Branco", "ac",
                [
                    (.mayor, "Tião Bocalom", "PL"),
                    (.viceMayor, "Alysson Bestene", "PP"),
                    (.cityCouncilor, "Aiache", "PP"),
                    (.cityCouncilor, "André Kamai", "PT"),
                    (.cityCouncilor, "Antonio Morais", "PL"),
                    (.cityCouncilor, "Bruno Moraes", "PP"),
                    (.cityCouncilor, "Eber Machado", "MDB"),
                    (.cityCouncilor, "Elzinha Mendonça", "PP"),
                    (.cityCouncilor, "Fábio Araújo", "MDB"),
                    (.cityCouncilor, "Felipe Tchê", "PP"),
                    (.cityCouncilor, "Joabe Lira", "UNIÃO"),
                    (.cityCouncilor, "João Paulo Silva", "PODE"),
                    (.cityCouncilor, "Joaquim Florencio", "PL"),
                    (.cityCouncilor, "Leôncio Castro", "PSDB"),
                    (.cityCouncilor, "Lucilene da Droga Vale", "PP"),
                    (.cityCouncilor, "Marcio Mustafá", "PSDB"),
                    (.cityCouncilor, "Matheus Paiva", "UNIÃO"),
                    (.cityCouncilor, "Moacir Junior", "SOLIDARIEDADE"),
                    (.cityCouncilor, "Nenem Almeida", "MDB"),
                    (.cityCouncilor, "Raimundo Nenem", "PL"),
                    (.cityCouncilor, "Rutênio Sá", "UNIÃO"),
                    (.cityCouncilor, "Samir Bestene", "PP"),
                    (.cityCouncilor, "Zé Lopes", "REPUBLICANOS"),
                ]),
            city(
                "1400100", "Boa Vista", "rr",
                [
                    (.mayor, "Arthur Henrique", "MDB"),
                    (.viceMayor, "Ten Cel Zeitoune", "PL"),
                    (.cityCouncilor, "Adjalma Gonçalves", "PODE"),
                    (.cityCouncilor, "Adnan Lima", "DC"),
                    (.cityCouncilor, "Aline Rezende", "PP"),
                    (.cityCouncilor, "Barbara Falcão", "PP"),
                    (.cityCouncilor, "Bruno Perez", "MDB"),
                    (.cityCouncilor, "Carol Dantas", "PSD"),
                    (.cityCouncilor, "Fogaça", "MDB"),
                    (.cityCouncilor, "Genilson Costa", "REPUBLICANOS"),
                    (.cityCouncilor, "Insp Daniel Mangabeira", "PDT"),
                    (.cityCouncilor, "Italo Otavio", "REPUBLICANOS"),
                    (.cityCouncilor, "Jeu Nunes", "PDT"),
                    (.cityCouncilor, "Júlio Cézar Medeiros", "MDB"),
                    (.cityCouncilor, "Manoel Neves", "REPUBLICANOS"),
                    (.cityCouncilor, "Marcelo Nunes", "PDT"),
                    (.cityCouncilor, "Melquisedek", "UNIÃO"),
                    (.cityCouncilor, "Pastora Carla Messias", "PP"),
                    (.cityCouncilor, "Pr Gill Rocha", "PODE"),
                    (.cityCouncilor, "Professor Thiago Reis", "PSD"),
                    (.cityCouncilor, "Roberto Franco", "DC"),
                    (.cityCouncilor, "Thiago Saraiva", "PSD"),
                    (.cityCouncilor, "Tuti Lopes", "PODE"),
                    (.cityCouncilor, "Vavá do Thianguá", "MDB"),
                    (.cityCouncilor, "Walkiria Ribeiro", "REPUBLICANOS"),
                ]),
            city(
                "2611606", "Recife", "pe",
                [
                    (.mayor, "João Campos", "PSB"),
                    (.viceMayor, "Victor Marques", "PC do B"),
                    (.cityCouncilor, "Aderaldo Pinto", "PSB"),
                    (.cityCouncilor, "Agora É Rubem", "PSB"),
                    (.cityCouncilor, "Alcides Teixeira Neto", "AVANTE"),
                    (.cityCouncilor, "Alef Collins", "PP"),
                    (.cityCouncilor, "Andreza Romero", "PSB"),
                    (.cityCouncilor, "Carlos Muniz", "PSB"),
                    (.cityCouncilor, "Cida Pedrosa", "PC do B"),
                    (.cityCouncilor, "Davi Muniz", "PSD"),
                    (.cityCouncilor, "Eduardo Mota", "PSB"),
                    (.cityCouncilor, "Eduardo Moura", "NOVO"),
                    (.cityCouncilor, "Eriberto Rafael", "PSB"),
                    (.cityCouncilor, "Fabiano Ferraz", "MDB"),
                    (.cityCouncilor, "Felipe Alecrim", "NOVO"),
                    (.cityCouncilor, "Felipe Francismar", "PSB"),
                    (.cityCouncilor, "Flávia de Nadegi", "PV"),
                    (.cityCouncilor, "Fred Ferreira", "PL"),
                    (.cityCouncilor, "Gilberto Alves", "PRD"),
                    (.cityCouncilor, "Gilson Machado Filho", "PL"),
                    (.cityCouncilor, "Hélio Guabiraba", "PSB"),
                    (.cityCouncilor, "Jô Cavalcanti", "PSOL"),
                    (.cityCouncilor, "Junior Bocão", "PSD"),
                    (.cityCouncilor, "Júnior de Cleto", "PSB"),
                    (.cityCouncilor, "Kari Santos", "PT"),
                    (.cityCouncilor, "Liana Cirne", "PT"),
                    (.cityCouncilor, "Luiz Eustaquio", "PSB"),
                    (.cityCouncilor, "Marco Aurélio Filho", "PV"),
                    (.cityCouncilor, "Natalia de Menudo", "PSB"),
                    (.cityCouncilor, "Paulo Muniz", "PL"),
                    (.cityCouncilor, "Professora Ana Lúcia", "REPUBLICANOS"),
                    (.cityCouncilor, "Rinaldo Junior", "PSB"),
                    (.cityCouncilor, "Rodrigo Coutinho", "REPUBLICANOS"),
                    (.cityCouncilor, "Romerinho Jatobá", "PSB"),
                    (.cityCouncilor, "Samuel Salazar", "MDB"),
                    (.cityCouncilor, "Tadeu Calheiros", "MDB"),
                    (.cityCouncilor, "Thiago Medina", "PL"),
                    (.cityCouncilor, "Wilton Brito", "PSB"),
                    (.cityCouncilor, "Zé Neto", "PSB"),
                ]),
            ShowcaseRoster.City(
                place: Place(code: "5300108", name: "Brasília", uf: "df"), officials: [],
                note: brasiliaNote),
        ]

        private static func city(
            _ code: String, _ name: String, _ uf: String, _ officials: [Official]
        ) -> ShowcaseRoster.City {
            let place = Place(code: code, name: name, uf: uf)
            return ShowcaseRoster.City(
                place: place,
                officials: ShowcaseRoster.cards(
                    officials.map { ($0.office, $0.name, $0.party) }, in: place),
                note: nil)
        }
    }
#endif
