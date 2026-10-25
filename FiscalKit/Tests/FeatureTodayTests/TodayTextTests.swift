import FiscalDomain
import Foundation
import Testing

@testable import FeatureToday

struct TodayTextTests {
    private let updated = Date(timeIntervalSince1970: 1_792_917_720)

    @Test func theSourceLineNamesEverySourceOnceWithTheLatestUpdate() throws {
        let sources = [
            Source(id: "camara", name: "Câmara dos Deputados", url: nil, updatedAt: updated),
            Source(
                id: "camara-2", name: "Câmara dos Deputados", url: nil,
                updatedAt: updated.addingTimeInterval(-60)),
            Source(id: "senado", name: "Senado Federal", url: nil, updatedAt: nil),
        ]
        let line = try #require(TodayText.sourceLine(sources))
        #expect(line.contains("Câmara dos Deputados"))
        #expect(line.contains("Senado Federal"))
        #expect(line.components(separatedBy: "Câmara dos Deputados").count == 2)
        #expect(line.contains(TodayText.stamp(updated)))
    }

    @Test func noSourceNoLine() {
        #expect(TodayText.sourceLine([]) == nil)
        #expect(TodayText.houseSourceLine([], suffix: "x") == nil)
    }

    @Test func aSourceWithoutDateStillShowsItsName() throws {
        let line = try #require(
            TodayText.sourceLine([Source(id: "tse", name: "TSE", url: nil, updatedAt: nil)]))
        #expect(line.contains("TSE"))
    }

    @Test func ballotsAreReadFromTheOfficialWords() {
        #expect(TodayBallot("Sim") == .yes)
        #expect(TodayBallot("Não") == .no)
        #expect(TodayBallot("NAO") == .no)
        #expect(TodayBallot("Abstenção") == .abstention)
        #expect(TodayBallot("Ausente") == .absent)
        #expect(TodayBallot("Obstrução") == .other("Obstrução"))
        #expect(TodayBallot("Obstrução").title == "Obstrução")
    }

    @Test func everyBallotHasItsOwnSymbol() {
        let ballots: [TodayBallot] = [.yes, .no, .abstention, .absent, .other("Art. 17")]
        #expect(Set(ballots.map(\.symbol)).count == ballots.count)
    }

    @Test func theLensLineOnlyAppearsWhenSomethingChanges() {
        #expect(TodayText.lensLine(nil) == nil)
        #expect(TodayText.lensLine(Lens(stance: .left)) == nil)
        #expect(TodayText.lensLine(Lens(themes: [.health], stance: .left)) != nil)
        #expect(TodayText.lensLine(Lens(stance: .impartial)) != nil)
    }

    @Test func everyKindHasATitleAndSymbol() {
        let kinds: [TodayDigest.Event.Kind] = [.vote, .session, .race, .law]
        #expect(Set(kinds.map(TodayText.symbol)).count == kinds.count)
        #expect(kinds.allSatisfy { !TodayText.kind($0).isEmpty })
    }
}
