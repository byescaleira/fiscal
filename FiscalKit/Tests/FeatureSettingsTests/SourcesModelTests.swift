import FiscalData
import FiscalDomain
import Foundation
import Testing

@testable import FeatureSettings

@MainActor
struct SourcesModelTests {
    @Test func staysEmptyWithoutAService() async {
        let sources = SourcesModel(service: nil)
        await sources.load()
        #expect(!sources.isAvailable)
        #expect(!sources.hasLoaded)
        #expect(sources.sources.isEmpty)
        #expect(sources.countText == nil)
        #expect(sources.updatedText == nil)
    }

    @Test func loadsUniqueSourcesInNameOrder() async {
        let sources = SourcesModel(service: ShowcasePublicData(scenario: .normal))
        await sources.load()
        #expect(sources.hasLoaded)
        #expect(sources.meta != nil)
        let names = sources.sources.map(\.name)
        #expect(!names.isEmpty)
        #expect(Set(sources.sources.map(\.id)).count == names.count)
        #expect(names == names.sorted { $0.localizedStandardCompare($1) == .orderedAscending })
        #expect(sources.countText == PublicFormat.number(names.count))
        #expect(sources.updatedText != nil)
        #expect(sources.peopleCount == sources.meta?.counts.people)
    }

    @Test func showsTheMethodOnlyWhenItExists() async {
        let empty = SourcesModel(service: nil)
        empty.showMethod()
        #expect(!empty.isShowingMethod)

        let sources = SourcesModel(service: ShowcasePublicData(scenario: .normal))
        await sources.load()
        sources.showMethod()
        #expect(sources.isShowingMethod == (sources.method != nil))
    }

    @Test func keepsTheScreenEmptyWhenTheServerFails() async {
        let sources = SourcesModel(service: ShowcasePublicData(scenario: .unavailable))
        await sources.load()
        #expect(sources.hasLoaded)
        #expect(sources.sources.isEmpty)
        #expect(sources.countText == nil)
    }
}
