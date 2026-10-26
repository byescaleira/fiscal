import FeatureCore
import Testing

struct AppIconTests {
    @Test func standardHasNoAlternateName() {
        #expect(AppIcon.standard.assetName == nil)
        #expect(AppIcon.standard.previewName == "FiscalIcon")
    }

    @Test(arguments: [
        (AppIcon.amazonDay, "FiscalIconAmazonDay"), (.themeIpe, "FiscalIconThemeIpe"),
        (.faunaJaguar, "FiscalIconFaunaJaguar"),
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

    @Test func everyRegisteredPartyHasAnIconInAlphabeticalOrder() {
        let parties = AppIcon.Collection.parties.icons
        #expect(parties.count == 30)
        #expect(Set(parties.map(\.title)).count == 30)
        let titles = parties.map(\.title)
        #expect(titles == titles.sorted { $0.localizedStandardCompare($1) == .orderedAscending })
        #expect(titles.first == "Agir")
        #expect(titles.last == "UP")
    }

    @Test func everyIconBelongsToOneCollection() {
        let grouped = AppIcon.Collection.allCases.flatMap(\.icons)
        #expect(grouped.count == AppIcon.allCases.count)
        #expect(Set(grouped) == Set(AppIcon.allCases))
    }

    @Test func partiesShowOnlyWithTheFlag() {
        #expect(!AppIcon.Collection.visible(partyIcons: false).contains(.parties))
        #expect(AppIcon.Collection.visible(partyIcons: true).contains(.parties))
        #expect(
            AppIcon.Collection.visible(partyIcons: false).count == AppIcon.Collection.allCases.count
                - 1)
        #expect(!FeatureFlag.partyIcons.defaultValue)
    }
}
