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
        #expect(store.drawsPortraits)
        #expect(store.hasTraits(slug: "lula", party: "PT"))
        #expect(!store.hasTraits(slug: "lula", party: "PL"))
        #expect(!store.hasTraits(slug: "nobody", party: "PSB"))
        let lula = store.animation(slug: "lula", party: "PT")
        #expect(lula != nil)
        let neutral = store.animation(slug: "nobody", party: "PSB")
        #expect(neutral != nil)
        #expect(neutral === store.animation(slug: "someone-else", party: "psb"))
        #expect(lula !== store.animation(slug: "lula", party: "PL"))
        #expect(!PortraitStore(library: .empty).drawsPortraits)
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
        for gesture in PortraitGesture.allCases {
            #expect(animation.frameTime(forMarker: gesture.rawValue) != nil, "\(gesture)")
        }
    }

    @Test func colorsTheRigWithTheTraitsAndTheParty() throws {
        let ink = "#2A2320"
        let skin = "#F6D8C4"
        let white = "#E7E3DD"
        let partyPrimary = "#D7191C"
        let fallbackPrimary = "#2A7069"
        let traits = PortraitLibrary.Traits(
            slug: "a", values: ["party": "PT", "skin": "1", "hairColor": "white"])
        let tones = try #require(
            PortraitTones([
                "ink": ink, "paper": "#FFFFFF", "skin": [skin],
                "hair": ["black": "#1F1A17", "white": white],
                "brow": ["white": "#A49E98"], "parties": ["pt": [partyPrimary, "#8E0A12"]],
                "fallback": [fallbackPrimary, "#62ABA2"],
                "neutral": [
                    "traits": ["face": "neutral", "hair": "none"],
                    "tones": ["skin": "primary>paper@1", "hair": "primary"],
                ],
            ]))
        let palette = try #require(tones.palette(for: traits, party: "PT"))
        #expect(palette.resolve("skin") == PortraitColor(hex: skin))
        #expect(palette.resolve("beard") == PortraitColor(hex: white))
        #expect(palette.resolve("primary") == PortraitColor(hex: partyPrimary))
        #expect(palette.resolve("primary>ink@0") == PortraitColor(hex: partyPrimary))
        #expect(palette.resolve("paper>ink@1") == PortraitColor(hex: ink))
        let other = try #require(tones.palette(for: traits, party: "Novo"))
        #expect(other.resolve("primary") == PortraitColor(hex: fallbackPrimary))
        let neutral = PortraitLibrary.Traits(slug: "b", values: ["face": "neutral"])
        let faceless = try #require(tones.palette(for: neutral, party: "PT"))
        #expect(faceless.resolve("skin") == PortraitColor(hex: "#FFFFFF"))
        #expect(faceless.resolve("hair") == PortraitColor(hex: partyPrimary))
    }

    @Test func rendersAStillForShareCards() throws {
        let store = PortraitStore()
        let image = try #require(store.still(slug: "lula", party: "PT"))
        #expect(image.width == Int(PortraitStore.stillSide))
        #expect(store.still(slug: "lula", party: "PT", pose: .celebrate) != nil)
        #expect(store.still(slug: "nobody", party: "PL") != nil)
    }
}
