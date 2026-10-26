import CoreText
import Foundation
import Testing

@testable import FiscalDesignSystem

@MainActor
struct EmphasisFontTests {
    private static let weightAxis = NSNumber(value: 0x7767_6874)

    private func axisWeight(_ trait: CGFloat) -> Double? {
        let attributes: [CFString: Any] = [
            kCTFontFamilyNameAttribute: EmphasisFont.family,
            kCTFontTraitsAttribute: [kCTFontWeightTrait: trait],
        ]
        let descriptor = CTFontDescriptorCreateWithAttributes(attributes as CFDictionary)
        let font = CTFontCreateWithFontDescriptor(descriptor, EmphasisFont.size(.title3), nil)
        guard (CTFontCopyFamilyName(font) as String) == EmphasisFont.family else { return nil }
        let variation = CTFontCopyVariation(font) as? [NSNumber: NSNumber]
        return variation?[Self.weightAxis]?.doubleValue
    }

    @Test func registersTheFamilyAndFollowsTheWeight() throws {
        EmphasisFont.register()
        let families = CTFontManagerCopyAvailableFontFamilyNames() as? [String] ?? []
        #expect(families.contains(EmphasisFont.family))
        let regular = try #require(axisWeight(0))
        let bold = try #require(axisWeight(0.4))
        #expect(bold > regular)
    }

    @Test func sizesFollowTheTextStyles() {
        #expect(EmphasisFont.size(.largeTitle) > EmphasisFont.size(.title))
        #expect(EmphasisFont.size(.title3) > EmphasisFont.size(.body))
    }
}
