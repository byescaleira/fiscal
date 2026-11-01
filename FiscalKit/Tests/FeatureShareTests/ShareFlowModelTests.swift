import FiscalData
import FiscalDomain
import Foundation
import Testing

@testable import FeatureShare

@MainActor
struct ShareFlowModelTests {
    @Test func theFollowingCardCarriesItsSourceAndDate() {
        let calendar = GregorianCalendar.current
        let content = ShareCardBuilder(calendar: calendar).following(
            [ShareFixtures.person("ana-souza", "Ana Souza")], at: ShareFixtures.now)
        let parts = calendar.dateComponents([.day, .month, .year], from: ShareFixtures.now)
        let date = String(
            format: "%02d/%02d/%04d", parts.day ?? 0, parts.month ?? 0, parts.year ?? 0)
        #expect(content.source.contains(date))
        #expect(ShareCaption.make(content).components(separatedBy: date).count == 2)
    }

    @Test func filesAreNamedAfterTheSubject() async throws {
        let person = ShareFixtures.model(.person(slug: "tabata-amaral"))
        await person.load()
        let name = try #require(person.content?.faces.first?.name)
        let file = ShareRenderer.fileName(for: try #require(person.content))
        #expect(file == "Fiscal - \(name).png")
        #expect(
            ShareRenderer.fileName(for: try #require(person.content), extension: "mp4")
                == "Fiscal - \(name).mp4")
        let follows = try await ShareFixtures.follows([
            ShareFixtures.person("ana-souza", "Ana Souza")
        ])
        for subject in try await ShareFixtures.subjects() {
            let model = ShareFixtures.model(subject, follows: follows)
            await model.load()
            let file = ShareRenderer.fileName(for: try #require(model.content))
            #expect(file.hasPrefix("Fiscal - "), "\(subject)")
            #expect(!file.contains("/"), "\(subject)")
            #expect(!file.contains(":"), "\(subject)")
        }
    }

    @Test func choosingADestinationSetsTheFormatAndKeepsTheSelection() async throws {
        let model = ShareFixtures.model(.person(slug: "tabata-amaral"))
        await model.load()
        let fact = try #require(model.facts.first)
        model.toggle(fact)
        model.style = .data
        model.choose(.whatsapp)
        #expect(model.format == .message)
        #expect(model.destination == .whatsapp)
        #expect(!model.isOn(fact))
        #expect(model.style == .data)
        #expect(!model.facts.contains(.code))
        model.choose(.instagramFeed)
        #expect(model.format == .feed)
        #expect(model.facts.contains(.code))
    }

    @Test func theCodeCanBeTurnedOff() async throws {
        let model = ShareFixtures.model(.person(slug: "tabata-amaral"))
        await model.load()
        #expect(model.card?.showsCode == true)
        model.toggle(.code)
        #expect(model.card?.showsCode == false)
        #expect(!model.isOn(.code))
    }

    @Test func theCaptionFollowsTheFactsUntilEdited() async throws {
        let model = ShareFixtures.model(.person(slug: "tabata-amaral"))
        await model.load()
        let original = model.caption
        #expect(!original.isEmpty)
        #expect(original.contains("https://fiscal.byescaleira.com/?person=tabata-amaral"))
        let fact = try #require(model.facts.first)
        model.toggle(fact)
        #expect(model.caption != original)
        model.editCaption("Mine")
        model.toggle(fact)
        #expect(model.caption == "Mine")
        model.editCaption(String(repeating: "a", count: 400))
        #expect(model.caption.count == ShareCaption.limit)
    }

    @Test(.timeLimit(.minutes(1))) func postingHandsTheFileToTheSheet() async throws {
        let model = ShareFixtures.model(.person(slug: "tabata-amaral"))
        await model.load()
        model.choose(.instagramFeed)
        await model.post()
        let request = try #require(model.postRequest)
        #expect(request.caption == model.caption)
        #expect(request.file.lastPathComponent.hasPrefix("Fiscal - "))
        #expect(FileManager.default.fileExists(atPath: request.file.path))
        #expect(model.exportProgress == 1)
        #expect(!model.isPosting)
        model.choose(.instagramStories)
        model.sendsVideo = false
        await model.post()
        #expect(model.postRequest?.caption == nil)
        #expect(model.postRequest?.file.pathExtension == "png")
    }

    private struct VideoFailure: Error {}

    private func delivery(saved: @escaping @MainActor (URL, Bool) -> Void = { _, _ in })
        -> ShareDelivery
    {
        ShareDelivery(
            writePasteboard: { _, _ in }, open: { _ in true }, canOpen: { _ in true },
            saveToPhotos: { file, isVideo in saved(file, isVideo) })
    }

    private func video() throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appending(path: "Fiscal.mp4")
        try Data([1]).write(to: file)
        return file
    }

    private func model(
        saved: @escaping @MainActor (URL, Bool) -> Void = { _, _ in },
        makeVideo: @escaping ShareModel.VideoMaker
    ) async -> ShareModel {
        let model = ShareModel(
            subject: .person(slug: "tabata-amaral"),
            service: ShowcasePublicData(scenario: .normal, now: ShareFixtures.now),
            delivery: delivery(saved: saved), metaAppID: nil, makeVideo: makeVideo)
        await model.load()
        model.render(scale: 1)
        return model
    }

    @Test func reelsMakeAVideoAndOpenTheSheetWithoutACaption() async throws {
        let file = try video()
        let model = await model { _, _, progress in
            progress(0.5)
            return file
        }
        model.choose(.instagramReels)
        await model.post()
        let request = try #require(model.postRequest)
        #expect(request.file == file)
        #expect(request.caption == nil)
        #expect(!model.videoFellBack)
        #expect(model.exportProgress == 1)
        #expect(!model.isExportingVideo)
    }

    @Test func aFailedVideoFallsBackToTheImageAndKeepsTheSelection() async throws {
        let model = await model { _, _, _ in throw VideoFailure() }
        let fact = try #require(model.facts.first)
        model.toggle(fact)
        model.choose(.instagramStories)
        await model.post()
        #expect(model.videoFellBack)
        #expect(model.postRequest?.file.pathExtension == "png")
        #expect(!model.isOn(fact))
    }

    @Test func aCancelledVideoDeliversNothing() async {
        let model = await model { _, _, _ in throw CancellationError() }
        model.choose(.tiktok)
        await model.post()
        #expect(model.postRequest == nil)
        #expect(model.notice == nil)
        #expect(!model.videoFellBack)
        #expect(!model.postFailed)
        #expect(model.exportProgress == 0)
    }

    @Test func theImageChoiceSkipsTheVideo() async throws {
        let model = await model { _, _, _ in
            Issue.record("the video must not be made")
            throw VideoFailure()
        }
        model.choose(.instagramStories)
        model.sendsVideo = false
        await model.post()
        #expect(model.postRequest?.file.pathExtension == "png")
    }

    #if canImport(UIKit) && !os(visionOS)
        @Test func tikTokSavesTheVideoAndCleansUp() async throws {
            let file = try video()
            var saved: (file: URL, isVideo: Bool)?
            let model = await model(saved: { saved = ($0, $1) }, makeVideo: { _, _, _ in file })
            model.choose(.tiktok)
            await model.post()
            #expect(saved?.file == file)
            #expect(saved?.isVideo == true)
            #expect(model.notice == .savedToPhotos(isVideo: true))
            #expect(model.postRequest == nil)
            #expect(!FileManager.default.fileExists(atPath: file.path(percentEncoded: false)))
        }
    #endif

    @Test func defaultStyleFollowsTheSubject() async throws {
        let person = ShareFixtures.model(.person(slug: "tabata-amaral"))
        await person.load()
        #expect(person.style == .typographic)
        #expect(person.styles == [.typographic, .data, .poster])
        let compare = ShareFixtures.model(.compare(slugs: ["kim-kataguiri", "erika-hilton"]))
        await compare.load()
        #expect(compare.style == .data)
        #expect(compare.styles == [.data, .typographic, .poster])
        let investigation = ShareFixtures.model(.investigation(ShareFixtures.investigation))
        await investigation.load()
        #expect(investigation.style == .typographic)
    }

    @Test func aChosenStyleSurvivesAReload() async {
        let model = ShareFixtures.model(.person(slug: "tabata-amaral"))
        await model.load()
        model.style = .data
        await model.load()
        #expect(model.style == .data)
    }

    @Test func storyColorsFollowTheStyle() async throws {
        let model = ShareFixtures.model(.person(slug: "tabata-amaral"))
        await model.load()
        for style in ShareStyle.allCases {
            let colors = try #require(model.card(style: style)?.storyColors)
            #expect(colors.top == style.storyField)
            #expect(colors.bottom == style.storyField)
        }
        #expect(ShareStyle.typographic.storyField != ShareStyle.data.storyField)
    }

    @Test func theCardTakesThePartiesOfTheSubject() async throws {
        let person = ShareFixtures.model(.person(slug: "tabata-amaral"))
        await person.load()
        let face = try #require(person.content?.faces.first)
        #expect(person.content?.stageParties == [face.party])
        let compare = ShareFixtures.model(.compare(slugs: ["kim-kataguiri", "erika-hilton"]))
        await compare.load()
        #expect(compare.content?.stageParties.count == 2)
        let place = ShareFixtures.model(.representatives(uf: "sp"))
        await place.load()
        #expect(place.content?.stageParties.isEmpty == true)
    }

    @Test func theFreeZoneShowsFacesOrSharesAndNeverANumber() async throws {
        let person = ShareFixtures.model(.person(slug: "tabata-amaral"))
        await person.load()
        let face = try #require(person.content?.faces.first)
        #expect(person.content?.zoneContent == .faces([face]))
        let vote = ShareFixtures.model(.vote(id: "camara-18732026"))
        await vote.load()
        guard case .shares(let segments)? = vote.content?.zoneContent else {
            Issue.record("expected the vote shares")
            return
        }
        #expect(segments.count == 3)
        let place = ShareFixtures.model(.representatives(uf: "sp"))
        await place.load()
        #expect(place.content?.zoneContent == ShareZoneContent.none)
    }
}
