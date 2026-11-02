import SwiftUI
import Testing

@testable import FeatureCore

struct AppSectionTests {
    @Test func routePlaceholderPerSection() {
        for section in AppSection.allCases {
            #expect(!section.routePlaceholderTitle.isEmpty)
            #expect(!section.routePlaceholderMessage.isEmpty)
        }
        #expect(
            Set(AppSection.allCases.map(\.routePlaceholderTitle)).count == AppSection.allCases.count
        )
    }

    @Test func sourceGroupsCoverEverySectionOnceInOrder() {
        let grouped = AppSection.SourceGroup.allCases.flatMap(\.sections)
        #expect(grouped == AppSection.allCases)
        #expect(AppSection.SourceGroup.followAlong.sections == [.feed])
        #expect(AppSection.SourceGroup.explore.sections == [.region, .search])
    }

    @Test func feedAndSearchUseTheirTabSymbols() {
        #expect(AppSection.feed.systemImage == "person.2")
        #expect(AppSection.search.systemImage == "binoculars")
    }

    @Test func feedIsTheFirstSection() {
        #expect(AppSection.allCases == [.feed, .votes, .money, .region, .search])
        #expect(AppSection.feed.rawValue == "feed")
    }

    @Test func shortcutsFollowTheSectionOrder() {
        #expect(AppSection.allCases.map(\.shortcut) == ["1", "2", "3", "4", "5"])
    }
}
