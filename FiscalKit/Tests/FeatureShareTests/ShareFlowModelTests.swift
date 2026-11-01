import Foundation
import Testing

@testable import FeatureShare

@MainActor
struct ShareFlowModelTests {
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
        await model.post()
        #expect(model.postRequest?.caption == nil)
        #expect(model.postRequest?.file.pathExtension == "png")
    }
}
