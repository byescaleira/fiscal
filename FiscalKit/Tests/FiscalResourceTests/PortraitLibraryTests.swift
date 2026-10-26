import FiscalResource
import Foundation
import Testing

struct PortraitLibraryTests {
    static let expressions = [
        "idle", "wave", "thumbsUp", "nodYes", "shakeNo", "smile", "celebrate", "sad", "think",
    ]

    @Test func bundlesOneRigAndTheTraitsOfEveryone() throws {
        let library = PortraitLibrary.bundled
        #expect(library.rigVersion == 1)
        #expect(library.slugs.count > 2000)
        #expect(library.slugs.contains("lula"))
        #expect(library.seal != nil)
        let rig = try #require(library.rig)
        let root = try #require(try JSONSerialization.jsonObject(with: rig) as? [String: Any])
        #expect(root["w"] as? Int == 200)
        #expect(root["h"] as? Int == 200)
        #expect(root["fiscal"] is [String: Any])
        let markers = try #require(root["markers"] as? [[String: Any]])
        let names = Set(markers.compactMap { $0["cm"] as? String })
        #expect(names.isSuperset(of: Self.expressions))
        #expect(names.contains("thinkLoop"))
    }

    @Test func everyTraitPicksAPartOfTheRig() throws {
        let library = PortraitLibrary.bundled
        let rig = try #require(library.rig)
        let root = try #require(try JSONSerialization.jsonObject(with: rig) as? [String: Any])
        let layers = try #require(root["layers"] as? [[String: Any]])
        let selectors = layers.compactMap { $0["fx"] as? [String: String] }
        for slug in ["lula", "allyson", "alan-rick"] {
            let traits = try #require(library.people[slug])
            let faces = selectors.filter {
                $0.keys.sorted() == ["face"] && $0["face"] == traits["face"]
            }
            #expect(!faces.isEmpty, "\(slug)")
        }
    }

    @Test func refusesTraitsWhenThePartyDiffers() {
        let library = PortraitLibrary.bundled
        #expect(library.traits(for: "lula", party: "PT") != nil)
        #expect(library.traits(for: "lula", party: "pt") != nil)
        #expect(library.traits(for: "lula", party: "PL") == nil)
        #expect(library.traits(for: "allyson", party: "Uniao") != nil)
        #expect(library.traits(for: "nobody", party: "PT") == nil)
    }

    @Test func decodesAndRejectsTraitTables() throws {
        let valid = Data(
            #"{"rigVersion":2,"fields":["slug","party","face"],"values":{"party":["PT"],"face":["oval"]},"people":[["a",0,0]]}"#
                .utf8)
        let library = try PortraitLibrary.decode(traits: valid, rig: nil, seal: nil)
        #expect(library.rigVersion == 2)
        #expect(library.traits(for: "a", party: "PT")?["face"] == "oval")
        let outOfRange = Data(
            #"{"rigVersion":1,"fields":["slug","party"],"values":{"party":["PT"]},"people":[["a",3]]}"#
                .utf8)
        #expect(throws: PortraitLibraryError.malformed) {
            try PortraitLibrary.decode(traits: outOfRange, rig: nil, seal: nil)
        }
        #expect(throws: PortraitLibraryError.malformed) {
            try PortraitLibrary.decode(traits: Data("[]".utf8), rig: nil, seal: nil)
        }
    }

    @Test func pointsAtTheStaticServerFiles() {
        #expect(PortraitLibrary.remoteRigPath == "avatars/rig.json")
        #expect(PortraitLibrary.remoteTraitsPath == "avatars/traits.json")
    }
}
