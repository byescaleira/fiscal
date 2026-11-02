import FiscalDomain
import Foundation
import Testing

@testable import FeatureToday

struct TodayModelTextTests {
    private let updated = Date(timeIntervalSince1970: 1_792_917_720)

    @Test func theSourceLineNamesEverySourceOnceWithTheLatestUpdate() throws {
        let sources = [
            Source(id: "camara", name: "Câmara dos Deputados", url: nil, updatedAt: updated),
            Source(
                id: "camara-2", name: "Câmara dos Deputados", url: nil,
                updatedAt: updated.addingTimeInterval(-60)),
            Source(id: "senado", name: "Senado Federal", url: nil, updatedAt: nil),
        ]
        let line = try #require(TodayModel.sourceLine(sources))
        #expect(line.contains("Câmara dos Deputados"))
        #expect(line.contains("Senado Federal"))
        #expect(line.components(separatedBy: "Câmara dos Deputados").count == 2)
        #expect(line.contains(TodayModel.stamp(updated)))
    }

    @Test func noSourceNoLine() {
        #expect(TodayModel.sourceLine([]) == nil)
        #expect(TodayModel.houseSourceLine([], suffix: "x") == nil)
    }

    @Test func aSourceWithoutDateStillShowsItsName() throws {
        let line = try #require(
            TodayModel.sourceLine([Source(id: "tse", name: "TSE", url: nil, updatedAt: nil)]))
        #expect(line.contains("TSE"))
    }

    @Test func everyKindHasATitleAndSymbol() {
        let kinds: [TodayDigest.Event.Kind] = [.vote, .session, .race, .law]
        #expect(Set(kinds.map(TodayModel.symbol)).count == kinds.count)
        #expect(kinds.allSatisfy { !TodayModel.kindTitle($0).isEmpty })
    }
}
