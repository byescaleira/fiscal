import FiscalData
import FiscalDomain
import Foundation
import Testing

@testable import FeatureMine

@MainActor
struct MineModelTests {
    @Test func startsEmptyAndHonest() async throws {
        let model = MineModel(follows: try FiscalDatabase.open(inMemory: true).repositories.follows)
        #expect(!model.hasLoaded)
        await model.load()
        #expect(model.hasLoaded)
        #expect(model.isEmpty)
    }

    @Test func listsWhoTheProfileFollows() async throws {
        let follows = try FiscalDatabase.open(inMemory: true).repositories.follows
        try await follows.follow(
            PersonCard(
                slug: "damares-alves", name: "Damares Alves", office: .senator, uf: "df",
                party: "REPUBLICANOS", photo: nil, status: .inOffice), at: .now)
        try await follows.follow(
            PersonCard(
                slug: "lula", name: "Lula", office: .president, uf: "br", party: "PT", photo: nil,
                status: .inOffice), at: .now)
        let model = MineModel(follows: follows)
        await model.load()
        #expect(model.followed.map(\.card.slug) == ["damares-alves", "lula"])
        let president = try #require(model.followed.last)
        #expect(!model.detail(for: president).contains("BR"))
        #expect(
            model.detail(for: try #require(model.followed.first)).hasSuffix("REPUBLICANOS · DF"))
    }
}
