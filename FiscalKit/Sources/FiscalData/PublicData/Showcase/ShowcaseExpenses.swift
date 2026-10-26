#if DEBUG
    import FiscalDomain
    import Foundation

    enum ShowcaseExpenses {
        private struct Supplier {
            let name: String
            let document: String?
            let category: String
        }

        private static let suppliers = [
            Supplier(
                name: "Voa Brasil Linhas Aéreas", document: "11222333000181",
                category: "Passagens aéreas"),
            Supplier(
                name: "Aerovia Cerrado Transportes Aéreos", document: "22333444000172",
                category: "Passagens aéreas"),
            Supplier(
                name: "Gráfica Planalto", document: "33444555000163",
                category: "Divulgação da atividade parlamentar"),
            Supplier(
                name: "Rádio Comunitária Horizonte", document: "44555666000154",
                category: "Divulgação da atividade parlamentar"),
            Supplier(
                name: "Posto Esplanada", document: "55666777000145",
                category: "Combustíveis e lubrificantes"),
            Supplier(
                name: "Locadora Cerrado", document: "66777888000136",
                category: "Locação de veículos"),
            Supplier(
                name: "Telefonia Capital", document: "77888999000127", category: "Telefonia"),
            Supplier(
                name: "Papelaria Central", document: "88999000000118",
                category: "Manutenção de escritório"),
            Supplier(
                name: "Maria Aparecida Souza", document: nil,
                category: "Manutenção de escritório"),
            Supplier(
                name: "João Pereira Lima", document: nil,
                category: "Consultorias, pesquisas e trabalhos técnicos"),
        ]

        private static let longSupplier = Supplier(
            name:
                "Cooperativa de Transporte e Locação de Veículos do Planalto Central e Entorno",
            document: "99000111000109", category: "Locação de veículos")

        static func list(
            for card: PersonCard, year: Int, now: Date, calendar: Calendar, longText: Bool
        ) -> ExpenseList {
            let current = calendar.component(.year, from: now)
            guard year <= current, year >= 2_023 else { return .empty }
            let lastMonth = year == current ? calendar.component(.month, from: now) : 12
            let seed = ShowcasePeople.seed(card.slug)
            let pool = longText ? [longSupplier] + suppliers : suppliers
            let link = documentURL(for: card)
            let items = (1...lastMonth).flatMap { month in
                (0..<(3 + (seed + month) % 4)).map { index in
                    let supplier = pool[(seed + month * 3 + index * 7) % pool.count]
                    return Expense(
                        id: "\(card.slug)-\(year)-\(month)-\(index)", year: year, month: month,
                        category: supplier.category, supplier: supplier.name,
                        document: supplier.document,
                        cents: 18_000 + ((seed * (index + 5) + month * 977) % 1_400) * 1_150,
                        url: index % 3 == 2 ? nil : link)
                }
            }
            return summary(of: items)
        }

        private static func documentURL(for card: PersonCard) -> URL? {
            card.office == .senator
                ? URL(string: "https://www6g.senado.leg.br/transparencia/sen/")
                : URL(string: "https://www.camara.leg.br/transparencia/gastos-parlamentares")
        }

        private static func summary(of items: [Expense]) -> ExpenseList {
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
    }
#endif
