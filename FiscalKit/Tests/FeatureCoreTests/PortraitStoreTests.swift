import FiscalDesignSystem
import FiscalResource
import Foundation
import Lottie
import Testing

@testable import FeatureCore

@MainActor
struct PortraitStoreTests {
    @Test func assemblesBundledPortraitsOnlyForTheSameParty() {
        let store = PortraitStore()
        #expect(store.hasPortrait(slug: "lula", party: "PT"))
        #expect(!store.hasPortrait(slug: "lula", party: "PL"))
        #expect(!store.hasPortrait(slug: "nobody", party: "PSB"))
        #expect(store.animation(slug: "lula", party: "PT") != nil)
        #expect(store.animation(slug: "lula", party: "PL") == nil)
        #expect(store.seal != nil)
    }

    @Test func everyExpressionIsAMarkerOfTheAssembledPortrait() throws {
        let animation = try #require(PortraitStore().animation(slug: "lula", party: "PT"))
        #expect(animation.size == CGSize(width: 200, height: 200))
        #expect(animation.frameTime(forMarker: PortraitExpression.idleMarker) == 0)
        for expression in PortraitExpression.allCases {
            #expect(animation.frameTime(forMarker: expression.marker) != nil, "\(expression)")
            #expect(animation.frameTime(forMarker: expression.poseMarker) != nil, "\(expression)")
        }
        #expect(animation.frameTime(forMarker: "thinkLoop") != nil)
    }

    @Test func colorsTheRigWithTheTraitsAndTheParty() throws {
        let traits = PortraitLibrary.Traits(
            slug: "a", values: ["party": "PT", "skin": "1", "hairColor": "white"])
        let tones = try #require(
            PortraitTones([
                "ink": "#2A2320", "paper": "#FFFFFF", "skin": ["#F6D8C4"],
                "hair": ["black": "#1F1A17", "white": "#E7E3DD"],
                "brow": ["white": "#A49E98"], "parties": ["pt": ["#D7191C", "#8E0A12"]],
                "fallback": ["#2A7069", "#62ABA2"],
            ]))
        let palette = try #require(tones.palette(for: traits, party: "PT"))
        #expect(palette.resolve("skin") == PortraitColor(hex: "#F6D8C4"))
        #expect(palette.resolve("beard") == PortraitColor(hex: "#E7E3DD"))
        #expect(palette.resolve("primary") == PortraitColor(hex: "#D7191C"))
        #expect(palette.resolve("primary>ink@0") == PortraitColor(hex: "#D7191C"))
        #expect(palette.resolve("paper>ink@1") == PortraitColor(hex: "#2A2320"))
        let other = try #require(tones.palette(for: traits, party: "Novo"))
        #expect(other.resolve("primary") == PortraitColor(hex: "#2A7069"))
    }

    @Test func rendersAStillForShareCards() throws {
        let store = PortraitStore()
        let image = try #require(store.still(slug: "lula", party: "PT"))
        #expect(image.width == Int(PortraitStore.stillSide))
        #expect(store.still(slug: "lula", party: "PT", pose: .celebrate) != nil)
        #expect(store.still(slug: "lula", party: "PL") == nil)
    }
}
