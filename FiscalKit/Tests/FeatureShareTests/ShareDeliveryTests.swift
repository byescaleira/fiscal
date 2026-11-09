import Foundation
import Testing

@testable import FeatureShare

@MainActor
final class ShareDeliveryRecorder {
    var items: [[String: Any]] = []
    var expiration: Date?
    var opened: [URL] = []
    var saved: [(URL, Bool)] = []
    var installed: Set<String> = ["instagram-stories", "facebook-stories", "tiktok"]
    var opens = true
    var saveError: Error?

    func delivery(now: Date) -> ShareDelivery {
        ShareDelivery(
            writePasteboard: { items, date in
                self.items = items
                self.expiration = date
            },
            open: { url in
                self.opened.append(url)
                return self.opens
            },
            canOpen: { url in self.installed.contains(url.scheme ?? "") },
            saveToPhotos: { file, isVideo in
                if let error = self.saveError { throw error }
                self.saved.append((file, isVideo))
            },
            now: { now })
    }
}

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct ShareDeliveryTests {
    private let now = Date(timeIntervalSince1970: 1_792_917_720)

    private func file(_ name: String, bytes: [UInt8]) throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appending(
                path: "FiscalDeliveryTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: name)
        try Data(bytes).write(to: url)
        return url
    }

    @Test func storiesWriteThePasteboardItems() async throws {
        let recorder = ShareDeliveryRecorder()
        let image = try file("Fiscal - Card.png", bytes: [0x89, 0x50, 0x4E, 0x47])
        let result = await recorder.delivery(now: now).send(
            image, isVideo: false, caption: "Fato", route: .instagramStories,
            metaAppID: "123456", topColor: "#101820", bottomColor: "#F2EDE4")

        #expect(result == .openedStories)
        let item = try #require(recorder.items.first)
        #expect(recorder.items.count == 1)
        #expect(
            item["com.instagram.sharedSticker.backgroundImage"] as? Data
                == Data([0x89, 0x50, 0x4E, 0x47]))
        #expect(item["com.instagram.sharedSticker.backgroundVideo"] == nil)
        #expect(item["com.instagram.sharedSticker.backgroundTopColor"] as? String == "#101820")
        #expect(item["com.instagram.sharedSticker.backgroundBottomColor"] as? String == "#F2EDE4")
        let expiration = try #require(recorder.expiration)
        #expect(abs(expiration.timeIntervalSince(now) - 300) < 1)
        #expect(
            recorder.opened.map(\.absoluteString)
                == ["instagram-stories://share?source_application=123456"])

        let video = try file("Fiscal - Card.mp4", bytes: [0, 0, 0, 0x18])
        let facebook = ShareDeliveryRecorder()
        let sent = await facebook.delivery(now: now).send(
            video, isVideo: true, caption: nil, route: .facebookStories, metaAppID: "123456",
            topColor: "#101820", bottomColor: "#F2EDE4")

        #expect(sent == .openedStories)
        let story = try #require(facebook.items.first)
        #expect(
            story["com.facebook.sharedSticker.backgroundVideo"] as? Data == Data([0, 0, 0, 0x18]))
        #expect(story["com.facebook.sharedSticker.backgroundImage"] == nil)
        #expect(story["com.facebook.sharedSticker.appID"] as? String == "123456")
        #expect(story["com.facebook.sharedSticker.backgroundTopColor"] as? String == "#101820")
        #expect(story["com.facebook.sharedSticker.backgroundBottomColor"] as? String == "#F2EDE4")
        #expect(
            facebook.opened.map(\.absoluteString)
                == ["facebook-stories://share?source_application=123456"])
    }

    @Test func fallsBackToTheShareSheet() async throws {
        let image = try file("Fiscal - Card.png", bytes: [1, 2, 3])

        for appID in [nil, "", "  "] as [String?] {
            let recorder = ShareDeliveryRecorder()
            let result = await recorder.delivery(now: now).send(
                image, isVideo: false, caption: nil, route: .instagramStories, metaAppID: appID,
                topColor: "#000000", bottomColor: "#000000")
            #expect(result == .needsShareSheet)
            #expect(recorder.items.isEmpty)
            #expect(recorder.opened.isEmpty)
        }

        let missing = ShareDeliveryRecorder()
        missing.installed = []
        let notInstalled = await missing.delivery(now: now).send(
            image, isVideo: false, caption: nil, route: .facebookStories, metaAppID: "123456",
            topColor: "#000000", bottomColor: "#000000")
        #expect(notInstalled == .needsShareSheet)
        #expect(missing.items.isEmpty)
        #expect(missing.opened.isEmpty)

        let refused = ShareDeliveryRecorder()
        refused.opens = false
        let notOpened = await refused.delivery(now: now).send(
            image, isVideo: false, caption: nil, route: .instagramStories, metaAppID: "123456",
            topColor: "#000000", bottomColor: "#000000")
        #expect(notOpened == .needsShareSheet)

        let sheet = ShareDeliveryRecorder()
        let direct = await sheet.delivery(now: now).send(
            image, isVideo: false, caption: "Fato", route: .shareSheet, metaAppID: "123456",
            topColor: "#000000", bottomColor: "#000000")
        #expect(direct == .needsShareSheet)
        #expect(sheet.items.isEmpty)
        #expect(sheet.opened.isEmpty)
    }

    @Test func savesToPhotosThenOpensTheApp() async throws {
        let video = try file("Fiscal - Card.mp4", bytes: [0, 0, 0, 0x18])
        let tiktok = try #require(URL(string: "tiktok://"))

        let recorder = ShareDeliveryRecorder()
        let opened = await recorder.delivery(now: now).send(
            video, isVideo: true, caption: nil, route: .photosThenOpen(tiktok), metaAppID: nil,
            topColor: "#000000", bottomColor: "#000000")
        #expect(opened == .savedToPhotos(openedApp: true))
        #expect(recorder.saved.map(\.0) == [video])
        #expect(recorder.saved.map(\.1) == [true])
        #expect(recorder.opened == [tiktok])

        let missing = ShareDeliveryRecorder()
        missing.installed = []
        let saved = await missing.delivery(now: now).send(
            video, isVideo: true, caption: nil, route: .photosThenOpen(tiktok), metaAppID: nil,
            topColor: "#000000", bottomColor: "#000000")
        #expect(saved == .savedToPhotos(openedApp: false))
        #expect(missing.saved.count == 1)
        #expect(missing.opened.isEmpty)

        let noApp = ShareDeliveryRecorder()
        let onlySaved = await noApp.delivery(now: now).send(
            video, isVideo: false, caption: nil, route: .photosThenOpen(nil), metaAppID: nil,
            topColor: "#000000", bottomColor: "#000000")
        #expect(onlySaved == .savedToPhotos(openedApp: false))

        let denied = ShareDeliveryRecorder()
        denied.saveError = ShareDeliveryError.photosAccessDenied
        let failed = await denied.delivery(now: now).send(
            video, isVideo: true, caption: nil, route: .photosThenOpen(tiktok), metaAppID: nil,
            topColor: "#000000", bottomColor: "#000000")
        #expect(
            failed == .failed(ShareDeliveryError.photosAccessDenied.errorDescription ?? ""))
        #expect(denied.opened.isEmpty)
    }

    @Test func readsTheMetaAppID() {
        #expect(ShareMetaApp.id(info: ["FiscalMetaAppID": "123456"]) == "123456")
        #expect(ShareMetaApp.id(info: ["FiscalMetaAppID": ""]) == nil)
        #expect(ShareMetaApp.id(info: [:]) == nil)
    }
}
