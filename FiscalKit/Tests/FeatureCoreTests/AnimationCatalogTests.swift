import FiscalResource
import Testing

@testable import FeatureCore

struct AnimationCatalogTests {
    @Test(arguments: FiscalAnimation.allCases)
    func everyAnimationIsEmbedded(animation: FiscalAnimation) {
        #expect(FiscalResourceAnimation.json(named: animation.rawValue) != nil)
    }

    @Test func everyGuideHasACategoryWithItself() {
        for guide in Guide.allCases {
            #expect(guide.category.guides.contains(guide))
        }
    }
}
