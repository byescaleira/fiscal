import Foundation
import Testing

@testable import FeatureShare

struct ShareDestinationTests {
    @Test func mapsEachDestination() {
        let table: [(ShareDestination, FeatureShare.ShareFormat, ShareMedia, Bool)] = [
            (.instagramStories, .stories, .either, false),
            (.instagramReels, .stories, .video, false),
            (.instagramFeed, .feed, .image, true),
            (.tiktok, .stories, .either, false),
            (.facebookStories, .stories, .either, false),
            (.facebookFeed, .feed, .image, true),
            (.whatsapp, .message, .image, true),
            (.whatsappStatus, .stories, .either, false),
            (.other, .feed, .image, true),
        ]
        #expect(table.count == ShareDestination.allCases.count)
        for (destination, format, media, caption) in table {
            #expect(destination.format == format, "\(destination)")
            #expect(destination.media == media, "\(destination)")
            #expect(destination.acceptsCaption == caption, "\(destination)")
        }
    }

    @Test func routesEachDestination() {
        #expect(ShareDestination.instagramStories.delivery == .instagramStories)
        #expect(ShareDestination.facebookStories.delivery == .facebookStories)
        #expect(ShareDestination.tiktok.delivery == .photosThenOpen(URL(string: "tiktok://")))
        let sheet: [ShareDestination] = [
            .instagramReels, .instagramFeed, .facebookFeed, .whatsapp, .whatsappStatus, .other,
        ]
        #expect(sheet.allSatisfy { $0.delivery == .shareSheet })
    }

    @Test func groupsByNetworkInOrder() {
        let grouped = ShareNetwork.allCases.flatMap { $0.destinations }
        #expect(grouped == ShareDestination.allCases)
        #expect(
            ShareNetwork.instagram.destinations == [
                .instagramStories, .instagramReels, .instagramFeed,
            ])
        #expect(ShareNetwork.whatsapp.destinations == [.whatsapp, .whatsappStatus])
    }

    @Test func mediaSaysWhatItAllows() {
        #expect(ShareMedia.image.allowsImage && !ShareMedia.image.allowsVideo)
        #expect(ShareMedia.video.allowsVideo && !ShareMedia.video.allowsImage)
        #expect(ShareMedia.either.allowsImage && ShareMedia.either.allowsVideo)
    }
}
