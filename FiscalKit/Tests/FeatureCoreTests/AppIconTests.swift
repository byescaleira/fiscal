import FeatureCore
import Testing

struct AppIconTests {
    @Test func standardHasNoAlternateName() {
        #expect(AppIcon.standard.assetName == nil)
        #expect(AppIcon.standard.previewName == "FiscalIcon")
    }

    @Test(arguments: [
        (AppIcon.lens, "FiscalIconLens"), (.iris, "FiscalIconIris"),
        (.ballot, "FiscalIconBallot"), (.monogram, "FiscalIconMonogram"),
    ])
    func conceptsMatchIconFiles(icon: AppIcon, name: String) {
        #expect(icon.assetName == name)
        #expect(icon.previewName == name)
    }

    @Test func assetNameRoundTrips() {
        for icon in AppIcon.allCases {
            #expect(AppIcon(assetName: icon.assetName) == icon)
        }
        #expect(AppIcon(assetName: "Unknown") == .standard)
    }
}
