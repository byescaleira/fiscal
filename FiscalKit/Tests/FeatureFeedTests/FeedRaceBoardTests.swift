import FiscalDomain
import Foundation
import Testing

@testable import FeatureFeed

struct FeedRaceBoardTests {
    @Test func thePresidentialRaceLeadsWhileItIsCounting() throws {
        let races = RaceScenario.close.races()
        let featured = try #require(FeedRaceBoard.featured(in: races))
        #expect(featured.id == "presidente-br")
        let board = FeedRaceBoard(race: featured, others: races.count - 1)
        #expect(board.sides.count == 2)
        #expect(board.sides.map(\.index) == [0, 1])
        #expect(board.sides.allSatisfy { $0.percent != PublicFormat.missing })
        #expect(board.othersText != nil)
        #expect(board.countedFraction > 0.8 && board.countedFraction < 0.9)
    }

    @Test func aFinishedRaceGivesWayToOneStillCounting() throws {
        let races = RaceScenario.decided.races()
        let featured = try #require(FeedRaceBoard.featured(in: races))
        #expect(!featured.final)
        #expect(featured.office == .governor)
    }

    @Test func theCardLeavesADayAfterEveryRaceIsOver() throws {
        let races = RaceScenario.finished.races()
        let result = Date(timeIntervalSince1970: 1_792_963_200)
        let winner = try #require(FeedRaceBoard.featured(in: races, now: result))
        #expect(winner.final)
        #expect(winner.office == .president)
        let nextDay = result.addingTimeInterval(FeedRaceBoard.winnerWindow)
        #expect(FeedRaceBoard.featured(in: races, now: nextDay) == nil)
        #expect(FeedRaceBoard.featured(in: [], now: result) == nil)
    }

    @Test func beforeTheCountTheNumbersAreMissingNotZero() throws {
        let race = try #require(FeedRaceBoard.featured(in: RaceScenario.waiting.races()))
        let board = FeedRaceBoard(race: race)
        #expect(board.sides.allSatisfy { $0.percent == PublicFormat.missing })
        #expect(board.othersText == nil)
        #expect(board.countedFraction == 0)
    }

    @Test func theLoserIsDimmedOnlyAfterTheFinalResult() throws {
        let race = try #require(
            RaceScenario.finished.races().first { $0.office == .president })
        let board = FeedRaceBoard(race: race)
        #expect(board.sides.filter(\.dimmed).count == 1)
        #expect(board.sides.first { $0.candidate.elected }?.dimmed == false)
    }

    @Test func candidateNamesBecomePortraitSlugs() {
        #expect(FeedRaceBoard.slug("Flavio Bolsonaro") == "flavio-bolsonaro")
        #expect(FeedRaceBoard.slug("Celina Leão") == "celina-leao")
        #expect(FeedRaceBoard.slug("Professora Maria do Carmo") == "professora-maria-do-carmo")
    }

    @Test func theSpokenSummaryNamesBothSides() throws {
        let race = try #require(FeedRaceBoard.featured(in: RaceScenario.close.races()))
        let label = FeedRaceBoard(race: race).accessibilityLabel
        for candidate in race.candidates.prefix(2) {
            #expect(label.contains(candidate.name))
        }
    }
}
