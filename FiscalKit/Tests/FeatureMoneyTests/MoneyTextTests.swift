import FiscalDomain
import Foundation
import Testing

@testable import FeatureMoney

struct MoneyTextTests {
    @Test func formatsACNPJAndKeepsAnythingElse() {
        #expect(MoneyText.cnpj("11222333000181") == "11.222.333/0001-81")
        #expect(MoneyText.cnpj("11.222.333/0001-81") == "11.222.333/0001-81")
        #expect(MoneyText.cnpj("123") == "123")
        #expect(MoneyText.cnpj(nil) == nil)
    }

    @Test func sourceLineNamesTheSourceAndTheUpdate() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Sao_Paulo"))
        let date = Date(timeIntervalSince1970: 1_792_918_800)
        let source = Source(id: "camara", name: "Câmara dos Deputados", url: nil, updatedAt: date)
        let line = MoneyText.sourceLine([source], calendar: calendar)
        #expect(line.contains("Câmara dos Deputados"))
        #expect(line.contains("25/10"))
        #expect(line.contains("18:00"))
        #expect(MoneyText.sourceLine([]).contains(PublicFormat.missing))
    }

    @Test func sourcesFallBackToTheWholeFile() {
        let camara = Source(id: "camara", name: "Câmara", url: nil, updatedAt: nil)
        let tse = Source(id: "tse", name: "TSE", url: nil, updatedAt: nil)
        #expect(MoneyText.sources([camara, tse], ids: ["tse"]) == [tse])
        #expect(MoneyText.sources([camara, tse], ids: ["receita"]) == [camara, tse])
    }

    @Test func monthNamesHaveTwelveEntries() {
        #expect(MoneyText.monthNames().count == 12)
        #expect(MoneyText.monthLabels().allSatisfy { !$0.contains(".") })
    }

    @Test func kindsMatchCommonCategoriesAndOrigins() {
        #expect(MoneyKind.category("Passagens aéreas").symbol == "airplane")
        #expect(MoneyKind.category("Divulgação da atividade parlamentar").symbol == "megaphone")
        #expect(MoneyKind.category("Locação de veículos").symbol == "car")
        #expect(MoneyKind.category("Algo novo").symbol == MoneyKind.other.symbol)
        #expect(MoneyKind.origin("Fundo Partidário").symbol == "flag")
        #expect(MoneyKind.origin("Pessoas físicas").symbol == "person.3")
        #expect(MoneyKind.office(.senator) == "building.columns")
    }

    @Test func barsKeepTheOriginalOrderOnTies() {
        let bars = MoneyText.bars(
            [("b", 10), ("a", 10), ("c", 30)], id: \.0, title: \.0, cents: \.1,
            kind: { _ in MoneyKind.other })
        #expect(bars.map(\.id) == ["c", "b", "a"])
    }
}
