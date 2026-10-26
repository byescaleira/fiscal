#if DEBUG
    import Foundation

    public enum RaceScenario: String, CaseIterable, Sendable {
        case waiting, early, close, tie, decided, finished, longNames, progressing, offline,
            unavailable, firstRound

        private typealias Person = (number: String, name: String, party: String)

        private struct Contest {
            let id: String
            let office: Race.Office
            let uf: String
            let first: Person
            let second: Person
            let sections: Int
            let lean: Double
            let others: [(person: Person, share: Double)]
        }

        private struct Shape {
            let counted: Double
            let share: Double
            let decided: Bool
            var firstRound = false
        }

        private static let contests: [Contest] = [
            Contest(
                id: "presidente-br", office: .president, uf: "br", first: ("13", "Lula", "PT"),
                second: ("22", "Flavio Bolsonaro", "PL"), sections: 499_248, lean: 0.512,
                others: [
                    (("55", "Helena Prado", "PSD"), 0.071), (("30", "Rui Tavares", "NOVO"), 0.033),
                    (("50", "Marina Couto", "PSOL"), 0.018),
                ]),
            Contest(
                id: "governador-ac", office: .governor, uf: "ac",
                first: ("10", "Alan Rick", "REPUBLICANOS"), second: ("11", "Mailza Assis", "PP"),
                sections: 2_270, lean: 0.47, others: [(("40", "Jorge Viana Filho", "PSB"), 0.064)]),
            Contest(
                id: "governador-am", office: .governor, uf: "am",
                first: ("22", "Professora Maria do Carmo", "PL"),
                second: ("55", "Omar Aziz", "PSD"),
                sections: 8_157, lean: 0.531,
                others: [
                    (("50", "Ana Lúcia Brito", "PSOL"), 0.048),
                    (("30", "Caio Menezes", "NOVO"), 0.021),
                ]),
            Contest(
                id: "governador-df", office: .governor, uf: "df",
                first: ("11", "Celina Leão", "PP"),
                second: ("13", "Leandro Grass", "PT"), sections: 6_969, lean: 0.495,
                others: [
                    (("40", "Rafael Parente", "PSB"), 0.083),
                    (("23", "Paula Belmonte", "CIDADANIA"), 0.037),
                ]),
            Contest(
                id: "governador-es", office: .governor, uf: "es",
                first: ("10", "Lorenzo Pazolini", "REPUBLICANOS"),
                second: ("15", "Ricardo Ferraço", "MDB"), sections: 9_844, lean: 0.552,
                others: [(("50", "Lúcia Matos", "PSOL"), 0.036)]),
            Contest(
                id: "governador-rn", office: .governor, uf: "rn",
                first: ("13", "Cadu de Lula", "PT"),
                second: ("44", "Allyson", "UNIÃO"), sections: 8_115, lean: 0.508,
                others: [
                    (("30", "Daniel Pinheiro", "NOVO"), 0.052),
                    (("50", "Clara Freire", "PSOL"), 0.029),
                ]),
            Contest(
                id: "governador-to", office: .governor, uf: "to",
                first: ("44", "Professora Dorinha", "UNIÃO"),
                second: ("45", "Vicentinho Júnior", "PSDB"), sections: 4_384, lean: 0.463,
                others: [(("40", "Wanderlei Silva", "PSB"), 0.057)]),
        ]

        private static let reference = Date(timeIntervalSince1970: 1_792_962_000)

        public static func named(_ value: String?) -> RaceScenario? {
            value.flatMap(RaceScenario.init(rawValue:))
        }

        public func races(step: Int = 0) -> [Race] {
            Self.contests.enumerated().map { index, contest in
                Self.race(
                    contest, index: index,
                    shape: shape(index: index, lean: contest.lean, step: step),
                    longNames: self == .longNames)
            }
        }

        public func state(raceID: String = "presidente-br", step: Int = 0) -> RaceActivityState? {
            races(step: step).first { $0.id == raceID }.map {
                RaceActivityState(race: $0, now: Self.reference)
            }
        }

        private func shape(index: Int, lean: Double, step: Int) -> Shape {
            switch self {
            case .waiting, .unavailable:
                return Shape(counted: 0, share: 0.5, decided: false)
            case .early:
                return Shape(counted: 0.032 + Double(index) * 0.01, share: lean, decided: false)
            case .close, .longNames, .offline:
                return Shape(counted: 0.87, share: index == 0 ? 0.5004 : lean, decided: false)
            case .tie:
                return Shape(counted: 0.5, share: 0.5, decided: false)
            case .decided:
                let done = index.isMultiple(of: 2)
                return Shape(counted: done ? 1 : 0.94, share: lean, decided: done)
            case .finished:
                return Shape(counted: 1, share: lean, decided: true)
            case .progressing:
                let counted = min(1, Double(step) * 0.1)
                return Shape(counted: counted, share: lean, decided: counted >= 1)
            case .firstRound:
                let done = index == 4
                return Shape(
                    counted: done ? 1 : 0.92, share: lean, decided: done, firstRound: true)
            }
        }

        private static func race(_ contest: Contest, index: Int, shape: Shape, longNames: Bool)
            -> Race
        {
            let counted = Int((Double(contest.sections) * shape.counted).rounded())
            let valid = counted * 290
            let blank = counted * (6 + index)
            let null = counted * (9 + index * 2)
            let turnout = valid + blank + null
            let suffix = longNames ? " da Silva Albuquerque de Oliveira" : ""
            let tallied = tally(shares(contest, shape: shape), valid: valid).sorted(by: Self.ranks)
            let candidates = tallied.enumerated().map { offset, entry in
                RaceCandidate(
                    number: entry.person.number, name: entry.person.name + suffix,
                    party: entry.person.party, votes: entry.votes, percent: entry.percent,
                    elected: shape.decided && offset == 0)
            }
            let sections = Race.Sections(
                total: contest.sections, counted: counted, percent: rounded(shape.counted * 100))
            let votes = Race.Votes(valid: valid, blank: blank, null: null, total: turnout)
            return Race(
                id: contest.id, office: contest.office, uf: contest.uf,
                round: shape.firstRound ? 1 : 2, sections: sections,
                electorate: contest.sections * 380, turnout: turnout,
                abstention: counted * 380 - turnout, votes: votes, candidates: candidates,
                final: shape.decided, sourceGeneratedAt: "2026-10-25T18:20:00-03:00")
        }

        private static func shares(_ contest: Contest, shape: Shape) -> [(
            person: Person, share: Double
        )] {
            guard shape.firstRound else {
                return [(contest.first, shape.share), (contest.second, 1 - shape.share)]
            }
            let base = 1 - contest.others.reduce(0) { $0 + $1.share }
            return [
                (contest.first, base * shape.share), (contest.second, base * (1 - shape.share)),
            ]
                + contest.others
        }

        private struct Tally {
            let person: Person
            let votes: Int
            let percent: Double
        }

        private static func tally(_ entries: [(person: Person, share: Double)], valid: Int)
            -> [Tally]
        {
            var result: [Tally] = []
            var remainingVotes = valid
            var remainingPercent = 100.0
            for (offset, entry) in entries.enumerated() {
                let isLast = offset == entries.count - 1
                let share = Double(valid) * entry.share
                let votes: Int = isLast ? remainingVotes : Int(share.rounded())
                remainingVotes -= votes
                let raw: Double =
                    isLast ? remainingPercent : Double(votes) / Double(max(valid, 1)) * 100
                let percent: Double = valid == 0 ? 0 : rounded(raw)
                remainingPercent -= percent
                result.append(Tally(person: entry.person, votes: votes, percent: percent))
            }
            return result
        }

        private static func ranks(_ lhs: Tally, _ rhs: Tally) -> Bool {
            lhs.votes == rhs.votes ? lhs.person.number < rhs.person.number : lhs.votes > rhs.votes
        }

        private static func rounded(_ value: Double) -> Double {
            (value * 100).rounded() / 100
        }
    }
#endif
