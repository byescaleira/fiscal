import FeatureCore
import Testing

@testable import FeatureGuides

struct GuidePagesTests {
    @Test(arguments: Guide.allCases)
    func everyGuideHasPages(guide: Guide) {
        #expect(!guide.pages.isEmpty)
        #expect(guide.minutes > 0)
    }

    @Test func everyCategoryHasGuides() {
        for category in GuideCategory.allCases {
            #expect(!category.guides.isEmpty)
        }
    }
}
