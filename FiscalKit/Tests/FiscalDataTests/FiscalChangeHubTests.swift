import CoreData
import FiscalDomain
import Foundation
import Testing

@testable import FiscalData

struct FiscalChangeHubTests {
    private let tabata = PersonCard(
        slug: "tabata-amaral", name: "Tabata Amaral", office: .federalDeputy, uf: "sp",
        party: "PSB", photo: nil, status: .inOffice)

    @Test func everyListenerHearsALocalChange() async {
        let hub = FiscalChangeHub(center: NotificationCenter())
        var first = hub.changes().makeAsyncIterator()
        var second = hub.changes().makeAsyncIterator()
        hub.publish(.local)
        #expect(await first.next() == .local)
        #expect(await second.next() == .local)
        #expect(hub.remoteRevision == 0)
        #expect(hub.localRevision == 1)
    }

    @Test func aRemoteStoreChangeCountsAsRemote() async {
        let center = NotificationCenter()
        let hub = FiscalChangeHub(center: center)
        var changes = hub.changes().makeAsyncIterator()
        center.post(name: .NSPersistentStoreRemoteChange, object: nil)
        #expect(await changes.next() == .remote)
        #expect(hub.remoteRevision == 1)
    }

    @Test func aSaveInTheStorePublishesALocalChange() async throws {
        let database = try FiscalDatabase.open(inMemory: true)
        var changes = database.changes.changes().makeAsyncIterator()
        try await database.repositories.follows.follow(tabata, at: .now)
        #expect(await changes.next() != nil)
        #expect(database.store.changeHub.localRevision == 1)
        try await database.repositories.follows.unfollow(slug: tabata.slug)
        #expect(database.store.changeHub.localRevision == 2)
    }
}
