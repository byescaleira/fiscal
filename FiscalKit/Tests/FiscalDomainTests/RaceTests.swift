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

    @Test func buildsTheActivityStateFromTheRace() throws {
        let state = RaceActivityState(race: try Self.race())
        #expect(state.sectionsPercent == 25.0)
        #expect(
            state.candidates.first
                == RaceStanding(number: "22", votes: 14_500_000, percent: 51.79, elected: false))
        #expect(state.updatedAt == 1_792_960_930)
        #expect(!state.final)
    }

    @Test func decodesThePushContentState() throws {
        let payload = Data(
            """
            {"sectionsPercent":99.5,"candidates":[{"number":"13","votes":10,"percent":50.5,"elected":true}],
            "final":true,"updatedAt":1792960000}
            """.utf8)
        let state = try JSONDecoder().decode(RaceActivityState.self, from: payload)
        #expect(state.final)
        #expect(state.candidates[0].elected)
        #expect(state.updatedDate == Date(timeIntervalSince1970: 1_792_960_000))
    }

    @Test func joinsStandingsWithTheContenders() throws {
        let state = RaceActivityState(race: try Self.race())
        let rows = state.rows(with: [
            RaceContender(number: "13", name: "Lula", party: "PT"),
            RaceContender(number: "22", name: "Flavio Bolsonaro", party: "PL"),
        ])
        #expect(rows.map(\.name) == ["Flavio Bolsonaro", "Lula"])
        #expect(state.rows(with: [])[0].name == "22")
    }

    @Test func namesTheScope() {
        #expect(RaceText.scope("df") == "Distrito Federal")
        #expect(RaceText.scope("xx") == "XX")
    }
}
