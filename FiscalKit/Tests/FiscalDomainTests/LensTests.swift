import FiscalDomain
import Foundation
import Testing

struct LensTests {
    @Test func keepsThreeToFiveDistinctThemes() {
        let lens = Lens(themes: [.health, .health, .taxes, .security, .education, .rights, .women])
        #expect(lens.themes == [.health, .taxes, .security, .education, .rights])
        #expect(lens.isComplete)
        #expect(!lens.canAddTheme)
        #expect(!Lens(themes: [.health, .taxes]).isComplete)
    }

    @Test func togglesWithinTheLimit() {
        var lens = Lens(themes: [.health, .taxes, .security, .education, .rights])
        lens.toggle(.women)
        #expect(!lens.contains(.women))
        lens.toggle(.taxes)
        #expect(lens.themes == [.health, .security, .education, .rights])
        lens.toggle(.women)
        #expect(lens.themes.last == .women)
    }

    @Test func ordersWithoutFiltering() {
        let lens = Lens(themes: [.security, .health, .taxes])
        let ordered = lens.ordered([.environment, .health, .culture, .security])
        #expect(ordered == [.security, .health, .environment, .culture])
    }

    @Test func supportIsOptionalAndCanBeWithheld() throws {
        #expect(!Lens().hasChoice)
        #expect(Lens(prefersNotToSay: true).hasChoice)
        #expect(Lens(prefersNotToSay: true).isNeutral)
        let lens = Lens(themes: [.health, .taxes, .security], prefersNotToSay: true)
        let data = try JSONEncoder().encode(lens)
        #expect(try JSONDecoder().decode(Lens.self, from: data) == lens)
    }

    @Test func decodingCleansAStoredLens() throws {
        let json =
            #"{ "themes": ["saude", "saude", "impostos", "seguranca", "educacao", "direitos", "mulheres"], "palette": "sertao" }"#
        let lens = try JSONDecoder().decode(Lens.self, from: Data(json.utf8))
        #expect(lens.themes.count == Lens.themeRange.upperBound)
        #expect(lens.supported.isEmpty)
        #expect(lens.palette == "sertao")
    }
}

struct ThemeTests {
    @Test func coversTheSeventeenKeysWithTheirOwnSymbols() {
        #expect(Theme.allCases.count == 17)
        #expect(Set(Theme.allCases.map(\.symbol)).count == 17)
        #expect(Theme(rawValue: "homenagens") == .tributes)
        #expect(Theme.allCases.allSatisfy { !$0.title.isEmpty })
    }
}

struct CalendarDayTests {
    @Test func readsAndWritesTheContractFormat() throws {
        let day = try #require(CalendarDay("2026-02-01"))
        #expect(day.description == "2026-02-01")
        #expect(
            CalendarDay("2026-10-25T17:42:10-03:00") == CalendarDay(year: 2_026, month: 10, day: 25)
        )
        #expect(CalendarDay("25/10/2026") == nil)
        #expect(CalendarDay(year: 2_026, month: 13, day: 1) == nil)
        #expect(try #require(CalendarDay("2026-01-31")) < day)
    }
}
