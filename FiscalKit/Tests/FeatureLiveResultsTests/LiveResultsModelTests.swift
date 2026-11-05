import FiscalDomain
import Foundation
import Testing

@testable import FeatureLiveResults

private actor FakeService: LiveResultsService {
    var result: Result<[Race], FiscalError>

    init(_ result: Result<[Race], FiscalError>) { self.result = result }

    func races() async throws -> [Race] { try result.get() }

    func set(_ result: Result<[Race], FiscalError>) { self.result = result }
}

private func race(id: String = "presidente-br", counted: Int = 10, final: Bool = false) -> Race {
    Race(
        id: id, office: id.hasPrefix("presidente") ? .president : .governor,
        uf: String(id.suffix(2)), round: 2,
        sections: .init(total: 100, counted: counted, percent: Double(counted)),
        electorate: 1000, turnout: 500, votes: .init(valid: 400, blank: 50, null: 50, total: 500),
        candidates: [
            RaceCandidate(
                number: "13", name: "Ana", party: "AA", votes: 250, percent: 62.5, elected: final),
            RaceCandidate(
                number: "22", name: "Bia", party: "BB", votes: 150, percent: 37.5, elected: false),
        ],
        final: final, sourceGeneratedAt: "2026-10-25T18:00:00-03:00")
}

@MainActor
struct LiveResultsModelTests {
    @Test func loadsAndSplitsTheRaces() async {
        let service = FakeService(.success([race(), race(id: "governador-ac")]))
        let model = LiveResultsModel(
            service: service)
        await model.refresh()
        #expect(model.hasLoaded)
        #expect(model.president?.id == "presidente-br")
        #expect(model.governors.map(\.id) == ["governador-ac"])
        #expect(!model.isOffline)
        #expect(!model.isWaiting)
    }

    @Test func waitsUntilTheCountStarts() async {
        let model = LiveResultsModel(
            service: FakeService(.success([race(counted: 0)])))
        await model.refresh()
        #expect(model.isWaiting)
        #expect(model.statusText(model.races[0]) == "Starts at 5 PM Brasília time")
    }

    @Test func keepsTheLastNumbersWhenOffline() async {
        let service = FakeService(.success([race()]))
        let model = LiveResultsModel(
            service: service)
        await model.refresh()
        await service.set(.failure(.onFetch))
        await model.refresh()
        #expect(model.isOffline)
        #expect(model.races.count == 1)
    }

    @Test func describesTheResult() {
        let model = LiveResultsModel(
            service: nil)
        #expect(!model.isConfigured)
        #expect(model.statusText(race(final: true)) == "Final result")
        #expect(model.statusText(race()) == "Counting")
    }

    @Test func announcesOnlyRacesThatJustEnded() {
        let before = [race(), race(id: "governador-ac", final: true)]
        let after = [race(final: true), race(id: "governador-ac", final: true)]
        #expect(
            LiveResultsModel.announcement(from: before, to: after)
                == "President · Brazil: Ana elected")
        #expect(LiveResultsModel.announcement(from: after, to: after) == nil)
        #expect(LiveResultsModel.announcement(from: [], to: after) == nil)
    }

    @Test func namesTheRaceAndTheCandidateForVoiceOver() async {
        let model = LiveResultsModel(
            service: nil)
        let winner = race(final: true).candidates[0]
        #expect(
            model.accessibilityLabel(winner, in: race(final: true)).hasPrefix(
                "Ana, AA, number 13, "))
        #expect(model.accessibilityLabel(winner, in: race(final: true)).hasSuffix(", Elected"))
        #expect(model.updatedText(race()) != nil)
    }

    @Test func showsDashesBeforeTheCountStarts() async {
        let model = LiveResultsModel(
            service: FakeService(.success([race(counted: 0)])))
        await model.refresh()
        let waiting = model.races[0]
        #expect(model.percentText(waiting.candidates[0], in: waiting) == "—")
        #expect(model.votesText(waiting.candidates[0], in: waiting) == "—")
        #expect(model.notice?.symbol == "clock")
        #expect(model.partyText(waiting.candidates[0]) == "AA · 13")
        let counting = race()
        #expect(model.percentText(counting.candidates[0], in: counting) != "—")
    }

    @Test func noticeShowsOfflineFirst() async {
        let service = FakeService(.success([race()]))
        let model = LiveResultsModel(
            service: service)
        await model.refresh()
        #expect(model.notice == nil)
        await service.set(.failure(.onFetch))
        await model.refresh()
        #expect(model.notice?.symbol == "wifi.slash")
    }

    @Test func namesTheScopeForTheSubtitle() {
        let model = LiveResultsModel(
            service: nil)
        #expect(model.scopeText == "All Regions · All Races")
        model.region = .north
        model.status = .decided
        #expect(model.scopeText == "North · Decided")
    }

    @Test func loadsTheDetailBeforeCallingItUnavailable() async {
        let service = FakeService(.success([race()]))
        let model = LiveResultsModel(
            service: service)
        guard case .loading = model.detailPhase(for: "governador-ac") else {
            Issue.record("Expected loading")
            return
        }
        await model.loadDetail(id: "governador-ac")
        guard case .unavailable = model.detailPhase(for: "governador-ac") else {
            Issue.record("Expected unavailable")
            return
        }
        guard case .ready(let summary) = model.detailPhase(for: "presidente-br") else {
            Issue.record("Expected ready")
            return
        }
        #expect(summary.race.id == "presidente-br")
        #expect(model.detailTitle(for: "presidente-br") == "President · Brazil")
        #expect(model.detailTitle(for: "governador-ac").isEmpty)
    }

    @Test func writesTheRaceTextsInTheSummary() {
        let live = RaceSummary(race: race())
        #expect(live.centerText == live.countedText)
        #expect(live.stackedCountText == "\(live.countedText) counted")
        #expect(live.isCounting)
        #expect(live.statusKicker == live.statusText.uppercased())
        #expect(live.monogram == "BR")
        #expect(live.officeLine == "\(live.office) · \(live.roundText)")
        #expect(live.ballotFooter != nil)
        #expect(live.cardAccessibility.hasPrefix(live.accessibilityLabel))
        let final = RaceSummary(race: race(final: true))
        #expect(final.centerText == "Final")
        #expect(final.stackedCountText == final.statusText)
        #expect(!final.isCounting)
        #expect(final.winnerAccessibility.contains("Ana"))
        #expect(RaceSummary(race: race(counted: 0)).ballotFooter == nil)
    }

    @Test func showsTheUnavailableStateWithoutAServer() async {
        let model = LiveResultsModel(
            service: nil)
        await model.refresh()
        #expect(model.hasLoaded)
        #expect(model.races.isEmpty)
    }
}
