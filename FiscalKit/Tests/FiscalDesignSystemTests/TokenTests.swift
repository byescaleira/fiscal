import FiscalDesignSystem
import SwiftUI
import Testing

struct TokenTests {
    @Test func spacingGrowsStepByStep() {
        let scale: [CGFloat] = [
            .spaceHairline, .space2XS, .spaceXS, .spaceS, .spaceM, .spaceL, .spaceInset, .spaceXL,
            .space2XL,
        ]
        #expect(scale == scale.sorted())
        #expect(Set(scale).count == scale.count)
    }

    @Test func radiiAndOpacitiesKeepTheirOrder() {
        #expect([CGFloat.radiusS, .radiusM, .radiusL, .radiusGroup].isSorted)
        #expect(
            [Double.opacityHidden, .opacityFill, .opacityTint, .opacitySoft, .opacityStrong]
                .isSorted)
    }

    @Test func invalidHexFallsBackToTheAccentColor() {
        #expect(Color(hex: "not a color") == .accentColor)
        #expect(Color(hex: nil) == .accentColor)
        #expect(Color(hex: "#C2602A") != .accentColor)
    }
}

extension Array where Element: Comparable {
    fileprivate var isSorted: Bool { self == sorted() }
}
