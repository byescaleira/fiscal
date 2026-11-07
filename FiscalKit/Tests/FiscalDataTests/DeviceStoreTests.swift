import FiscalDomain
import Foundation
import SwiftData
import Testing

@testable import FiscalData

struct DeviceStoreTests {
    private let tabata = PersonCard(
        slug: "tabata-amaral", name: "Tabata Amaral", office: .federalDeputy, uf: "sp",
        party: "PSB", photo: nil, status: .inOffice)
    private let nikolas = PersonCard(
        slug: "nikolas-ferreira", name: "Nikolas Ferreira", office: .federalDeputy, uf: "mg",
        party: "PL", photo: URL(string: "https://example.test/nikolas.jpg"), status: .inOffice)

    @Test func savesAndReplacesTheSupport() async throws {
        let support = try FiscalDatabase.open(inMemory: true).repositories.support
        #expect(try await support.support() == nil)
        try await support.save(SupportChoice(people: ["pessoa-a"], causes: [.health, .taxes]))
        let next = SupportChoice(causes: [.education, .environment, .rights])
        try await support.save(next)
        #expect(try await support.support() == next)
        try await support.reset()
        #expect(try await support.support() == nil)
    }

    @Test func followsOncePerPersonInAlphabeticalOrder() async throws {
        let follows = try FiscalDatabase.open(inMemory: true).repositories.follows
        let date = Date(timeIntervalSince1970: 1_792_917_720)
        try await follows.follow(tabata, at: date)
        try await follows.follow(nikolas, at: date.addingTimeInterval(60))
        try await follows.follow(tabata, at: date.addingTimeInterval(120))
        let followed = try await follows.followed()
        #expect(followed.map(\.card.slug) == ["nikolas-ferreira", "tabata-amaral"])
        #expect(followed.last?.followedAt == date)
        #expect(followed.first?.card == nikolas)
        #expect(try await follows.isFollowing(slug: "tabata-amaral"))
        try await follows.unfollow(slug: "tabata-amaral")
        #expect(try await !follows.isFollowing(slug: "tabata-amaral"))
        #expect(try await follows.followed().count == 1)
    }

    @Test func keepsBothOnDiskAcrossLaunches() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "DeviceStoreTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        do {
            let repositories = try FiscalDatabase.open(cloudSync: false, directory: directory)
                .repositories
            try await repositories.support.save(
                SupportChoice(causes: [.health, .taxes, .security]))
            try await repositories.follows.follow(tabata, at: .now)
        }
        let reopened = try FiscalDatabase.open(cloudSync: false, directory: directory).repositories
        #expect(try await reopened.support.support()?.causes == [.health, .taxes, .security])
        #expect(try await reopened.follows.followed().map(\.card.slug) == ["tabata-amaral"])
        let files = try FileManager.default.contentsOfDirectory(atPath: directory.path())
        #expect(files.contains("Device.store"))
        #expect(files.contains("Fiscal.store"))
    }

    @Test func theSupportNeverJoinsTheSyncedStore() {
        let synced = FiscalSchemaV5.cloudModels.map { String(describing: $0) }
        let device = FiscalSchemaV5.deviceModels.map { String(describing: $0) }
        #expect(device.contains("SupportEntity"))
        #expect(device.contains("LensEntity"))
        #expect(!synced.contains("SupportEntity"))
        #expect(!synced.contains("LensEntity"))
        #expect(device.contains("LikeEntity"))
        #expect(!synced.contains("LikeEntity"))
        #expect(synced.contains("FollowEntity"))
    }
}
