import Testing

@testable import FeatureSettings

struct ReleaseTests {
    private let releases = [
        Release(version: "1.0", headline: "First", notes: []),
        Release(version: "1.2", headline: "Second", notes: []),
        Release(version: "1.10", headline: "Third", notes: []),
    ]

    @Test func featuresTheNewestReleaseNotAfterTheInstalledVersion() {
        #expect(Release.featured(for: "1.2.5", in: releases)?.version == "1.2")
        #expect(Release.featured(for: "1.10", in: releases)?.version == "1.10")
        #expect(Release.featured(for: "0.9", in: releases)?.version == "1.0")
    }

    @Test func listsEarlierReleasesNewestFirst() {
        #expect(Release.earlier(than: "1.10", in: releases).map(\.version) == ["1.2", "1.0"])
        #expect(Release.earlier(than: "1.0", in: releases).isEmpty)
    }

    @Test func everyReleaseHasNotesWithSymbols() {
        #expect(!Release.all.isEmpty)
        for release in Release.all {
            #expect(!release.notes.isEmpty)
            #expect(Set(release.notes.map(\.id)).count == release.notes.count)
        }
    }
}
