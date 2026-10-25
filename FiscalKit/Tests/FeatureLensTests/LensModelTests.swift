import FiscalData
import FiscalDomain
import Foundation
import Testing

@testable import FeatureLens

@MainActor
struct LensModelTests {
    @Test func startsWithNoTopicsChosen() async throws {
        let model = LensModel(repository: try FiscalDatabase.open(inMemory: true).repositories.lens)
        await model.load()
        #expect(model.hasLoaded)
        #expect(model.lens.themes.isEmpty)
        #expect(model.themes.count == Theme.allCases.count)
        #expect(!model.canSave)
    }

    @Test func choosesThreeToFiveTopics() async throws {
        let model = LensModel(repository: try FiscalDatabase.open(inMemory: true).repositories.lens)
        await model.load()
        for theme in [Theme.health, .taxes] { model.toggle(theme) }
        #expect(!model.canSave)
        for theme in [Theme.security, .education, .rights] { model.toggle(theme) }
        #expect(model.canSave)
        #expect(!model.canToggle(.women))
        #expect(model.canToggle(.health))
        model.toggle(.women)
        #expect(!model.isChosen(.women))
    }

    @Test func savesTheLensOnTheDevice() async throws {
        let repository = try FiscalDatabase.open(inMemory: true).repositories.lens
        let model = LensModel(repository: repository)
        await model.load()
        for theme in [Theme.environment, .countryside, .economy] { model.toggle(theme) }
        await model.save()
        #expect(model.isSaved)
        #expect(try await repository.lens()?.themes == [.environment, .countryside, .economy])
        model.toggle(.economy)
        #expect(!model.isSaved)
    }
}
