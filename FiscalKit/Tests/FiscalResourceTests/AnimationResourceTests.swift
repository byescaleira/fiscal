import FiscalResource
import Foundation
import Testing

struct AnimationResourceTests {
    @Test(arguments: ["backup", "done", "editor", "launch", "privacy", "widgets"])
    func embedsAPlayableAnimation(name: String) throws {
        let json = try #require(FiscalResourceAnimation.json(named: name))
        let object = try #require(
            try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        #expect(object["w"] as? Int == 320)
        #expect(object["h"] as? Int == 180)
        #expect(object["fr"] as? Int == 60)
    }

    @Test func returnsNothingForUnknownNames() {
        #expect(FiscalResourceAnimation.json(named: "missing") == nil)
    }
}
