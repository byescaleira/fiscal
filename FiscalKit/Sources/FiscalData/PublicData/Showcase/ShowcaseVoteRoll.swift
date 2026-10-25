#if DEBUG
    import FiscalDomain
    import Foundation

    enum ShowcaseVoteRoll {
        private static let chamberParties: [(String, Int)] = [
            ("PL", 92), ("PT", 68), ("UNIÃO", 59), ("PP", 50), ("PSD", 45),
            ("REPUBLICANOS", 44), ("MDB", 44), ("PDT", 17), ("PSB", 15), ("PODEMOS", 15),
            ("PSOL", 13), ("PSDB", 13), ("AVANTE", 8), ("PCdoB", 7), ("SOLIDARIEDADE", 5),
            ("NOVO", 5), ("CIDADANIA", 4), ("PV", 4), ("PRD", 4), ("REDE", 1),
        ]

        private static let senateParties: [(String, Int)] = [
            ("PSD", 15), ("PL", 14), ("MDB", 11), ("PT", 9), ("UNIÃO", 7), ("PP", 7),
            ("REPUBLICANOS", 4), ("PODEMOS", 4), ("PSB", 4), ("PDT", 3), ("PSDB", 2),
            ("NOVO", 1),
        ]

        private static let chamberStates: [(String, Int)] = [
            ("sp", 70), ("mg", 53), ("rj", 46), ("ba", 39), ("rs", 31), ("pr", 30), ("pe", 25),
            ("ce", 22), ("ma", 18), ("go", 17), ("pa", 17), ("sc", 16), ("pb", 12), ("es", 10),
            ("pi", 10), ("al", 9), ("am", 8), ("df", 8), ("ms", 8), ("mt", 8), ("rn", 8),
            ("ro", 8), ("to", 8), ("ac", 8), ("ap", 8), ("rr", 8), ("se", 8),
        ]

        private static let firstNames = [
            "Ana", "Bruno", "Carla", "Diego", "Elisa", "Fábio", "Gabriela", "Heitor", "Íris",
            "Jonas", "Lívia", "Márcio", "Nádia", "Otávio", "Paula", "Rafael", "Sílvia",
            "Tiago", "Vera", "Wagner", "Yara", "Zeca",
        ]

        private static let lastNames = [
            "Albuquerque", "Barros", "Campos", "Duarte", "Esteves", "Farias", "Guedes",
            "Holanda", "Lacerda", "Macedo", "Nogueira", "Pacheco", "Queiroz", "Rezende",
            "Sampaio", "Teixeira", "Vasconcelos", "Xavier", "Leite", "Moraes", "Prado",
            "Siqueira", "Torres", "Cunha",
        ]

        static func complete(_ named: [VoteDetail.Ballot], for vote: VoteSummary)
            -> [VoteDetail.Ballot]
        {
            let parties = remaining(
                vote.house == .camara ? chamberParties : senateParties, minus: named.map(\.party))
            let states = remaining(
                vote.house == .camara
                    ? chamberStates : ShowcasePeople.states.map { ($0.uf, 3) },
                minus: named.map(\.uf))
            let count = min(parties.count, states.count)
            guard count > 0 else { return named }
            let stride = coprimeStride(for: states.count)
            let seats = (0..<count).map { index in
                (party: parties[index], uf: states[(index * stride) % states.count])
            }
            let votes = choices(for: seats.map(\.party), vote: vote, named: named)
            let ballots = seats.enumerated().map { index, seat in
                VoteDetail.Ballot(
                    slug: nil, name: name(index, vote: vote), party: seat.party, uf: seat.uf,
                    vote: votes[index])
            }
            return named + ballots
        }

        private static func remaining(_ counts: [(String, Int)], minus taken: [String]) -> [String]
        {
            counts.flatMap { key, count in
                Array(repeating: key, count: max(0, count - taken.count { $0 == key }))
            }
        }

        private static func coprimeStride(for count: Int) -> Int {
            var stride = 7
            while gcd(stride, count) != 1 { stride += 1 }
            return stride
        }

        private static func gcd(_ lhs: Int, _ rhs: Int) -> Int {
            rhs == 0 ? lhs : gcd(rhs, lhs % rhs)
        }

        private static func choices(
            for parties: [String], vote: VoteSummary, named: [VoteDetail.Ballot]
        ) -> [String] {
            let namedVotes = named.map(\.vote)
            let yes = max(0, (vote.yes ?? 0) - namedVotes.count { $0 == "Sim" })
            let no = max(0, (vote.no ?? 0) - namedVotes.count { $0 == "Não" })
            let others = max(
                0,
                (vote.others ?? 0)
                    - namedVotes.count { $0 != "Sim" && $0 != "Não" && $0 != "Ausente" })
            let absent = max(0, parties.count - yes - no - others)
            var result = Array(repeating: "Ausente", count: parties.count)
            let absentSeats = Set((0..<absent).map { $0 * parties.count / max(absent, 1) })
            let present = parties.indices.filter { !absentSeats.contains($0) }
                .sorted { lhs, rhs in
                    (lean(parties[lhs], vote: vote), lhs % 11) < (
                        lean(parties[rhs], vote: vote), rhs % 11
                    )
                }
            for (order, seat) in present.enumerated() {
                if order < yes {
                    result[seat] = "Sim"
                } else if order < yes + others {
                    result[seat] = order.isMultiple(of: 2) ? "Abstenção" : "Obstrução"
                } else {
                    result[seat] = "Não"
                }
            }
            return result
        }

        private static func lean(_ party: String, vote: VoteSummary) -> Int {
            ShowcasePeople.seed("\(party)-\(vote.id)")
        }

        private static func name(_ index: Int, vote: VoteSummary) -> String {
            let offset = vote.house == .camara ? 0 : 5
            let first = firstNames[(index + offset) % firstNames.count]
            let last = lastNames[(index / firstNames.count) % lastNames.count]
            let middle = lastNames[(index * 7 + offset + 2) % lastNames.count]
            return "\(first) \(middle) \(last)"
        }
    }
#endif
