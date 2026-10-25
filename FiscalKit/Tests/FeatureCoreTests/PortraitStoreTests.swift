import FiscalResource
import Foundation
import Testing

@testable import FeatureCore

@MainActor
struct PortraitStoreTests {
    @Test func findsBundledPortraitsOnlyForTheSameParty() {
        let store = PortraitStore()
        #expect(store.hasPortrait(slug: "lula", party: "PT"))
        #expect(store.hasPortrait(slug: "flavio-bolsonaro", party: "PL"))
        #expect(!store.hasPortrait(slug: "lula", party: "PL"))
        #expect(!store.hasPortrait(slug: "tabata-amaral", party: "PSB"))
        #expect(store.animation(slug: "lula", party: "PT") != nil)
        #expect(store.animation(slug: "lula", party: "PL") == nil)
        #expect(store.seal != nil)
    }

    @Test func installsAServerPortraitAndChecksIt() throws {
        let store = PortraitStore(library: .empty)
        let entry = PortraitLibrary.Entry(
            slug: "tabata-amaral", party: "PSB", updatedAt: "2026-10-25")
        #expect(throws: PortraitStoreError.invalidAnimation) {
            try store.install(Data("{}".utf8), for: entry)
        }
        #expect(!store.hasPortrait(slug: "tabata-amaral", party: "PSB"))
        let generic = try #require(PortraitLibrary.bundled.generic)
        try store.install(generic, for: entry)
        #expect(store.hasPortrait(slug: "tabata-amaral", party: "PSB"))
        #expect(!store.hasPortrait(slug: "tabata-amaral", party: "PT"))
        #expect(store.downloaded["tabata-amaral"] == entry)
    }

    @Test func rendersAStillForShareCards() throws {
        let store = PortraitStore()
        let image = try #require(store.still(slug: "lula", party: "PT"))
        #expect(image.width == Int(PortraitStore.stillSide))
        #expect(store.still(slug: "lula", party: "PL") == nil)
    }

}
