#if DEBUG
    import Foundation

    public enum RaceScenario: String, CaseIterable, Sendable {
        case waiting, early, close, tie, decided, finished, longNames, progressing, offline,
            unavailable

        private struct Contest {
            let id: String
            let office: Race.Office
            let uf: String
            let first: (number: String, name: String, party: String)
            let second: (number: String, name: String, party: String)
            let sections: Int
            let lean: Double
        }

        private struct Shape {
            let counted: Double
            let share: Double
            let decided: Bool
        }

        private static let contests: [Contest] = [
            Contest(
                id: "presidente-br", office: .president, uf: "br", first: ("13", "Lula", "PT"),
                second: ("22", "Flavio Bolsonaro", "PL"), sections: 499_248, lean: 0.512),
            Contest(
                id: "governador-ac", office: .governor, uf: "ac",
                first: ("10", "Alan Rick", "REPUBLICANOS"), second: ("11", "Mailza Assis", "PP"),
                sections: 2_270, lean: 0.47),
            Contest(
                id: "governador-am", office: .governor, uf: "am",
                first: ("22", "Professora Maria do Carmo", "PL"),
                second: ("55", "Omar Aziz", "PSD"),
                sections: 8_157, lean: 0.531),
            Contest(
                id: "governador-df", office: .governor, uf: "df",
                first: ("11", "Celina Leão", "PP"),
                second: ("13", "Leandro Grass", "PT"), sections: 6_969, lean: 0.495),
            Contest(
                id: "governador-es", office: .governor, uf: "es",
                first: ("10", "Lorenzo Pazolini", "REPUBLICANOS"),
                second: ("15", "Ricardo Ferraço", "MDB"), sections: 9_844, lean: 0.552),
            Contest(
                id: "governador-rn", office: .governor, uf: "rn",
                first: ("13", "Cadu de Lula", "PT"),
                second: ("44", "Allyson", "UNIÃO"), sections: 8_115, lean: 0.508),
            Contest(
                id: "governador-to", office: .governor, uf: "to",
                first: ("44", "Professora Dorinha", "UNIÃO"),
                second: ("45", "Vicentinho Júnior", "PSDB"), sections: 4_384, lean: 0.463),
        ]

        private static let reference = Date(timeIntervalSince1970: 1_792_962_000)

        public static func named(_ value: String?) -> RaceScenario? {
            value.flatMap(RaceScenario.init(rawValue:))
        }

        public func races(step: Int = 0) -> [Race] {
            Self.contests.enumerated().map { index, contest in
                Self.race(
                    contest, shape: shape(index: index, lean: contest.lean, step: step),
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
            }
        }

        private static func race(_ contest: Contest, shape: Shape, longNames: Bool) -> Race {
            let counted = Int((Double(contest.sections) * shape.counted).rounded())
            let valid = counted * 290
            let firstVotes = Int((Double(valid) * shape.share).rounded())
            let secondVotes = valid - firstVotes
            let firstPercent = valid == 0 ? 0 : rounded(Double(firstVotes) / Double(valid) * 100)
            let secondPercent = valid == 0 ? 0 : rounded(100 - firstPercent)
            let firstWins = firstVotes >= secondVotes
            let suffix = longNames ? " da Silva Albuquerque de Oliveira" : ""
            let first = RaceCandidate(
                number: contest.first.number, name: contest.first.name + suffix,
                party: contest.first.party, votes: firstVotes, percent: firstPercent,
                elected: shape.decided && firstWins)
            let second = RaceCandidate(
                number: contest.second.number, name: contest.second.name + suffix,
                party: contest.second.party, votes: secondVotes, percent: secondPercent,
                elected: shape.decided && !firstWins)
            let ordered = [first, second].sorted(by: Self.ranks)
            let sections = Race.Sections(
                total: contest.sections, counted: counted, percent: rounded(shape.counted * 100))
            let votes = Race.Votes(
                valid: valid, blank: counted * 8, null: counted * 12, total: counted * 310)
            return Race(
                id: contest.id, office: contest.office, uf: contest.uf, round: 2,
                sections: sections, electorate: contest.sections * 320, turnout: counted * 310,
                votes: votes, candidates: ordered, final: shape.decided,
                sourceGeneratedAt: "2026-10-25T18:20:00-03:00")
        }

        private static func ranks(_ lhs: RaceCandidate, _ rhs: RaceCandidate) -> Bool {
            lhs.votes == rhs.votes ? lhs.number < rhs.number : lhs.votes > rhs.votes
        }

        private static func rounded(_ value: Double) -> Double {
            (value * 100).rounded() / 100
        }
    }
#endif
