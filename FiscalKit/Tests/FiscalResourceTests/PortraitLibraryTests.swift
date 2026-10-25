import FiscalResource
import Foundation
import Testing

struct PortraitLibraryTests {
    static let secondRound = [
        "alan-rick", "allyson", "cadu-de-lula", "celina-leao", "flavio-bolsonaro", "leandro-grass",
        "lorenzo-pazolini", "lula", "mailza-assis", "omar-aziz", "professora-dorinha",
        "professora-maria-do-carmo", "ricardo-ferraco", "vicentinho-junior",
    ]

    @Test func bundlesTheSecondRoundPeople() {
        let library = PortraitLibrary.bundled
        #expect(library.rigVersion == 1)
        #expect(library.slugs == Self.secondRound)
        #expect(library.generic != nil)
        #expect(library.seal != nil)
    }

    @Test func everyPortraitIsASquareFiveSecondLoop() throws {
        let library = PortraitLibrary.bundled
        for slug in library.slugs {
            let party = try #require(library.entries[slug]?.party)
            let data = try #require(library.animationData(for: slug, party: party))
            let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
            #expect(root["w"] as? Int == 200, "\(slug)")
            #expect(root["h"] as? Int == 200, "\(slug)")
            let frames = (root["op"] as? Double ?? 0) / (root["fr"] as? Double ?? 1)
            #expect((4...6).contains(frames), "\(slug)")
            let layers = try #require(root["layers"] as? [[String: Any]])
            let names = Set(layers.compactMap { $0["nm"] as? String })
            #expect(names.isSuperset(of: ["backdrop", "party", "skin", "ink", "lips"]), "\(slug)")
        }
    }

    @Test func everyAnimatedValueEndsWhereItStarts() throws {
        let library = PortraitLibrary.bundled
        let documents = try library.slugs.map { slug in
            try #require(
                library.animationData(for: slug, party: library.entries[slug]?.party ?? ""))
        }
        for data in documents + [library.generic, library.seal].compactMap(\.self) {
            let root = try JSONSerialization.jsonObject(with: data)
            for keys in Self.keyframeTracks(in: root) {
                let first = keys.first?["s"] as? [Double]
                let last = keys.last?["s"] as? [Double]
                #expect(first == last)
            }
        }
    }

    @Test func refusesAPortraitWhenThePartyDiffers() {
        let library = PortraitLibrary.bundled
        #expect(library.animationData(for: "lula", party: "PT") != nil)
        #expect(library.animationData(for: "lula", party: "pt") != nil)
        #expect(library.animationData(for: "lula", party: "PL") == nil)
        #expect(library.animationData(for: "allyson", party: "Uniao") != nil)
        #expect(library.animationData(for: "nobody", party: "PT") == nil)
    }

    @Test func decodesAndRejectsLibraries() throws {
        let valid = Data(
            #"{"rigVersion":2,"people":[{"slug":"a","party":"PT","updatedAt":"2026-10-25"}],"animations":{"a":{"v":"5.9.0"}}}"#
                .utf8)
        let library = try PortraitLibrary.decode(valid)
        #expect(library.rigVersion == 2)
        #expect(library.animationData(for: "a", party: "PT") != nil)
        let missing = Data(
            #"{"rigVersion":1,"people":[{"slug":"a","party":"PT","updatedAt":"x"}],"animations":{}}"#
                .utf8)
        #expect(throws: PortraitLibraryError.missingAnimation("a")) {
            try PortraitLibrary.decode(missing)
        }
        #expect(throws: PortraitLibraryError.malformed) {
            try PortraitLibrary.decode(Data("[]".utf8))
        }
    }

    @Test func pointsAtTheStaticServerFiles() {
        #expect(PortraitLibrary.remotePath(for: "lula") == "avatars/lula.json")
        #expect(PortraitLibrary.remoteIndexPath == "avatars/index.json")
    }

    private static func keyframeTracks(in value: Any) -> [[[String: Any]]] {
        if let object = value as? [String: Any] {
            var tracks: [[[String: Any]]] = []
            if object["a"] as? Int == 1, let keys = object["k"] as? [[String: Any]] {
                tracks.append(keys)
            }
            return tracks + object.values.flatMap { keyframeTracks(in: $0) }
        }
        if let array = value as? [Any] {
            return array.flatMap { keyframeTracks(in: $0) }
        }
        return []
    }
}
