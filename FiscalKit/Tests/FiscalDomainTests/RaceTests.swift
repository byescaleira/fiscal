import Foundation
import Testing

@testable import FiscalDomain

struct RaceTests {
    static let json = Data(
        """
        {"races":[{"id":"presidente-br","office":"president","uf":"br","round":2,
        "sections":{"total":499248,"counted":124812,"percent":25.0},
        "electorate":158745502,"turnout":30000000,
        "votes":{"valid":28000000,"blank":1000000,"null":1000000,"total":30000000},
        "candidates":[
        {"number":"22","name":"Flavio Bolsonaro","party":"PL","votes":14500000,"percent":51.79,"elected":false},
        {"number":"13","name":"Lula","party":"PT","votes":13500000,"percent":48.21,"elected":false}],
        "final":false,"sourceGeneratedAt":"2026-10-25T17:42:10-03:00"}],
        "fetchedAt":"2026-10-25T20:42:15Z"}
        """.utf8)

    static func race() throws -> Race {
        try JSONDecoder().decode(RaceList.self, from: json).races[0]
    }

    @Test func decodesTheServerContract() throws {
        let race = try Self.race()
        #expect(race.office == .president)
        #expect(race.sections.counted == 124812)
        #expect(race.candidates.map(\.number) == ["22", "13"])
        #expect(race.votes.null == 1_000_000)
        #expect(race.hasStarted)
        #expect(race.elected == nil)
        #expect(race.leader?.number == "22")
    }

    @Test func parsesTheSourceTimeWithItsOffset() throws {
        let race = try Self.race()
        #expect(race.generatedAt == Date(timeIntervalSince1970: 1_792_960_930))
    }

    @Test func namesTheScope() {
        #expect(RaceText.scope("df") == "Distrito Federal")
        #expect(RaceText.scope("xx") == "XX")
    }
}
