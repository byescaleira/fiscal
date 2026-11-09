import FeatureCore
import FiscalDomain
import Foundation
import Testing

@testable import FeatureMemory

@MainActor
struct PeriodModelTests {
    @Test func loadsThePeriodWithItsNeighbors() async throws {
        let model = PeriodModel(
            id: "vargas-era", service: MemoryService(timeline: try MemoryFixture.timeline()))
        #expect(model.phase == .idle)
        await model.load()
        #expect(model.phase == .loaded)
        #expect(model.period?.id == "vargas-era")
        #expect(model.previous?.id == "first-republic")
        #expect(model.next?.id == "new-republic")
        #expect(model.presidentsLine == String(appLocalized: "\(1) heads of government"))
        for indicator in model.period?.indicators ?? [] {
            #expect(model.footnote(indicator).contains(indicator.note))
        }
    }

    @Test func theEdgesHaveOnlyOneNeighbor() async throws {
        let service = MemoryService(timeline: try MemoryFixture.timeline())
        let first = PeriodModel(id: "first-republic", service: service)
        let last = PeriodModel(id: "new-republic", service: service)
        await first.load()
        await last.load()
        #expect(first.previous == nil)
        #expect(first.next?.id == "vargas-era")
        #expect(last.next == nil)
        #expect(last.presidentsLine == String(appLocalized: "\(3) heads of government"))
    }

    @Test func anUnknownPeriodLoadsWithoutAPeriod() async throws {
        let model = PeriodModel(
            id: "empire", service: MemoryService(timeline: try MemoryFixture.timeline()))
        await model.load()
        #expect(model.phase == .loaded)
        #expect(model.period == nil)
        #expect(model.years == PublicFormat.missing)
    }

    @Test func aFailingServiceKeepsTheError() async {
        let model = PeriodModel(id: "vargas-era", service: MemoryService.failing)
        await model.load()
        #expect(model.phase == .failed(.offline))
        #expect(model.period == nil)
    }

    @Test func withoutAServiceItIsUnavailable() async {
        let model = PeriodModel(id: "vargas-era", service: nil)
        await model.load()
        #expect(model.phase == .failed(.unavailable))
    }
}

@MainActor
struct StudyGuideModelTests {
    private func loaded() async throws -> StudyGuideModel {
        let model = StudyGuideModel(
            id: "how-voting-works", service: MemoryService(study: try MemoryFixture.study()))
        await model.load()
        return model
    }

    @Test func loadsTheGuide() async throws {
        let model = try await loaded()
        #expect(model.phase == .loaded)
        #expect(model.guide?.title == "How voting works")
        #expect(model.terms.count == 2)
    }

    @Test func numbersTheCardsAndQuestions() async throws {
        let guide = try #require(try await loaded().guide)
        #expect(guide.cardPosition(0) == "1/\(guide.cards.count)")
        if let first = guide.quiz.first {
            #expect(guide.questionTitle(0) == "1. \(first.question)")
        }
        #expect(guide.questionTitle(guide.quiz.count).isEmpty)
    }

    @Test func searchesTermsIgnoringAccentsAndCase() async throws {
        let model = try await loaded()
        model.query = "  COLIGACAO "
        #expect(model.terms.map(\.term) == ["Coligação"])
        model.query = "votos válidos"
        #expect(model.terms.map(\.term) == ["Quociente eleitoral"])
    }

    @Test func countsRightAnswersOnlyOncePerQuestion() async throws {
        let model = try await loaded()
        model.choose(1, for: 0)
        model.choose(0, for: 0)
        #expect(model.answered == 1)
        #expect(model.correct == 1)
        model.choose(1, for: 1)
        #expect(model.correct == 1)
        #expect(model.progressLine == String(appLocalized: "\(1) of \(2) right"))
        model.restart()
        #expect(model.answered == 0)
    }

    @Test func aFailingServiceKeepsTheError() async {
        let model = StudyGuideModel(id: "how-voting-works", service: MemoryService.failing)
        await model.load()
        #expect(model.phase == .failed(.offline))
        #expect(model.guide == nil)
    }

    @Test func aMissingCatalogLoadsWithoutAGuide() async {
        let model = StudyGuideModel(id: "how-voting-works", service: MemoryService())
        await model.load()
        #expect(model.phase == .loaded)
        #expect(model.guide == nil)
        #expect(model.terms.isEmpty)
    }

    @Test func withoutAServiceItIsUnavailable() async {
        let model = StudyGuideModel(id: "how-voting-works", service: nil)
        await model.load()
        #expect(model.phase == .failed(.unavailable))
    }
}
