import FiscalData
import FiscalDomain
import Foundation
import Testing

@testable import FeatureProfile

@MainActor
struct ProfileModelTests {
    private let showcase = ShowcasePublicData(
        scenario: .normal, now: Date(timeIntervalSince1970: 1_792_917_720))

    @Test func loadsTheProfileWithItsFacts() async {
        let model = ProfileModel(slug: "tabata-amaral", service: showcase)
        #expect(model.isEmpty)
        await model.load()
        #expect(model.phase == .loaded)
        #expect(model.title == "Tabata Amaral")
        #expect(model.subtitle?.contains("PSB · SP") == true)
        #expect(
            model.facts.map(\.id) == [
                "attendance", "proposals", "votes", "quota", "salary", "assets",
            ])
        #expect(model.facts.allSatisfy { $0.value != "—" })
        #expect(!model.sources.isEmpty)
    }

    @Test func showsADashWhereTheHouseDoesNotPublish() async {
        let model = ProfileModel(slug: "tarcisio-de-freitas", service: showcase)
        await model.load()
        let values = Dictionary(uniqueKeysWithValues: model.facts.map { ($0.id, $0.value) })
        #expect(values["attendance"] == "—")
        #expect(values["salary"] == "—")
        #expect(values["assets"] != "—")
    }

    @Test func followsAndUnfollowsOnTheDevice() async throws {
        let follows = try FiscalDatabase.open(inMemory: true).repositories.follows
        let model = ProfileModel(slug: "kim-kataguiri", service: showcase, follows: follows)
        #expect(!model.canFollow)
        await model.load()
        #expect(model.canFollow)
        #expect(!model.isFollowing)
        await model.toggleFollow()
        #expect(model.isFollowing)
        #expect(try await follows.followed().map(\.card.name) == ["Kim Kataguiri"])
        await model.toggleFollow()
        #expect(!model.isFollowing)
        #expect(try await follows.followed().isEmpty)
    }

    @Test func aMissingProfileSaysSo() async {
        let model = ProfileModel(slug: "nobody", service: showcase)
        await model.load()
        #expect(model.phase == .failed(.notFound))
        #expect(model.isEmpty)
    }
}
