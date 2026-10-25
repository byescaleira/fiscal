import FiscalResource
import Foundation
import SwiftUI
import Testing

struct BrazilMapTests {
    static let ufs = [
        "ac", "al", "am", "ap", "ba", "ce", "df", "es", "go", "ma", "mg", "ms", "mt", "pa", "pb",
        "pe",
        "pi", "pr", "rj", "rn", "ro", "rr", "rs", "sc", "se", "sp", "to",
    ]

    @Test func bundlesTheCountryAndEveryState() throws {
        let map = try #require(BrazilMap.bundled)
        #expect(map.ufs == Self.ufs)
        #expect(map.country.states.keys.sorted() == Self.ufs)
        #expect(map.source.url.host() == "servicodados.ibge.gov.br")
    }

    @Test func outlinesAreNormalizedAndLight() throws {
        let map = try #require(BrazilMap.bundled)
        var total = 0
        for uf in Self.ufs {
            let outline = try #require(map.outline(of: uf))
            #expect(max(outline.width, outline.height) == 1, "\(uf)")
            #expect(!outline.rings.isEmpty, "\(uf)")
            for ring in outline.rings {
                #expect(ring.count >= 3, "\(uf)")
                for point in ring {
                    #expect(point.count == 2)
                    #expect(point.allSatisfy { (0...1).contains($0) }, "\(uf)")
                }
            }
            total += outline.pointCount
        }
        #expect(total < 8_000)
    }

    @Test func countryOutlineKeepsTheFrameWhenHighlighting() throws {
        let map = try #require(BrazilMap.bundled)
        let whole = map.countryOutline()
        let one = map.countryOutline(["sp"])
        #expect(one.width == whole.width)
        #expect(one.height == whole.height)
        #expect(one.pointCount < whole.pointCount)
        #expect(map.outline(of: "SP") == map.outline(of: "sp"))
    }

    @Test func shapeFitsTheRect() throws {
        let map = try #require(BrazilMap.bundled)
        let outline = try #require(map.outline(of: "ba"))
        let rect = CGRect(x: 0, y: 0, width: 300, height: 200)
        let bounds = MapShape(outline).path(in: rect).boundingRect
        #expect(!bounds.isEmpty)
        #expect(rect.insetBy(dx: -1, dy: -1).contains(bounds))
        #expect(MapShape(MapOutline(width: 1, height: 1, rings: [])).path(in: rect).isEmpty)
    }
}
