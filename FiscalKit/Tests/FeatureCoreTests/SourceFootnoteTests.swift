import FeatureCore
import FiscalDomain
import Foundation
import Testing

struct SourceFootnoteTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo") ?? .gmt
        return calendar
    }

    @Test func namesEachSourceOnceWithTheLatestUpdate() throws {
        let early = try Date("2026-10-24T09:00:00-03:00", strategy: .iso8601)
        let late = try Date("2026-10-25T06:00:00-03:00", strategy: .iso8601)
        let text = try #require(
            SourceFootnote.text(
                [
                    Source(id: "camara", name: "Câmara dos Deputados", url: nil, updatedAt: early),
                    Source(id: "tse", name: "TSE", url: nil, updatedAt: late),
                    Source(id: "camara", name: "Câmara dos Deputados", url: nil, updatedAt: nil),
                ], calendar: calendar))
        #expect(text.contains("Câmara dos Deputados, TSE"))
        #expect(text.contains("25/10, 06:00"))
    }

    @Test func staysQuietWithoutSources() {
        #expect(SourceFootnote.text([], calendar: calendar) == nil)
        let text = SourceFootnote.text(
            [Source(id: "tse", name: "TSE", url: nil, updatedAt: nil)], calendar: calendar)
        #expect(text?.contains("TSE") == true)
        #expect(text?.contains("/") == false)
    }

    @Test func writesDaysTheBrazilianWay() throws {
        let day = try #require(CalendarDay(year: 2_026, month: 3, day: 7))
        #expect(SourceFootnote.day(day) == "07/03/2026")
    }
}
