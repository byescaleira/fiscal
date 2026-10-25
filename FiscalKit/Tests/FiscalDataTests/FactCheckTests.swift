import FiscalDomain
import Foundation
import Testing

@testable import FiscalData

struct FactCheckTests {
    private let host = PublicDataStub.makeHost()

    private func client() throws -> PublicDataClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PublicDataStub.self]
        configuration.urlCache = URLCache(
            memoryCapacity: 1_024 * 1_024, diskCapacity: 0, directory: nil)
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return PublicDataClient(
            baseURL: try #require(URL(string: "https://\(host)/api")),
            session: URLSession(configuration: configuration))
    }

    private let sample = #"""
        {
          "items": [
            {
              "id": "comprova-20389", "title": "Vídeo de Lula no Paraguai é usado fora de contexto",
              "verdict": "Falso", "date": "2026-09-30",
              "url": "https://projetocomprova.com.br/publica%C3%A7%C3%B5es/video-de-lula/",
              "publisher": "Projeto Comprova", "license": "CC BY-ND 4.0",
              "licenseUrl": "https://creativecommons.org/licenses/by-nd/4.0/deed.pt-br"
            },
            {
              "id": "comprova-20025", "title": "Vídeo de estudante usa imagens geradas por IA",
              "verdict": null, "date": "2025-11-19",
              "url": "https://projetocomprova.com.br/publica%C3%A7%C3%B5es/video-de-estudante/",
              "publisher": "Projeto Comprova", "license": "CC BY-ND 4.0",
              "licenseUrl": "https://creativecommons.org/licenses/by-nd/4.0/deed.pt-br"
            }
          ],
          "sources": [
            { "id": "comprova", "name": "Projeto Comprova", "url": "https://projetocomprova.com.br",
              "updatedAt": "2026-10-25T06:30:00-03:00" }
          ]
        }
        """#

    @Test func decodesTheChecksOfAPerson() async throws {
        PublicDataStub.reply(
            .init(status: 200, body: Data(sample.utf8)), to: "/api/v1/people/lula/checks.json",
            on: host)
        let list = try #require(try await client().checks(slug: "lula"))
        #expect(list.items.map(\.id) == ["comprova-20389", "comprova-20025"])
        let first = try #require(list.items.first)
        #expect(first.verdict == "Falso")
        #expect(first.date == CalendarDay(year: 2_026, month: 9, day: 30))
        #expect(first.url.host() == "projetocomprova.com.br")
        #expect(first.publisher == "Projeto Comprova")
        #expect(first.license == "CC BY-ND 4.0")
        #expect(
            first.licenseUrl.absoluteString
                == "https://creativecommons.org/licenses/by-nd/4.0/deed.pt-br")
        #expect(list.items.last?.verdict == nil)
        #expect(list.sources.map(\.id) == ["comprova"])
        #expect(PublicDataStub.seen(on: host).map(\.path) == ["/api/v1/people/lula/checks.json"])
    }

    @Test func aMissingFileMeansNoChecks() async throws {
        PublicDataStub.fallback(.init(status: 404), on: host)
        let list = try await client().checks(slug: "kim-kataguiri")
        #expect(list == nil)
    }

    @Test func otherFailuresStillThrow() async throws {
        PublicDataStub.fallback(.init(status: 503), on: host)
        await #expect(throws: PublicDataError.unavailable) {
            try await client().checks(slug: "lula")
        }
        PublicDataStub.fallback(.init(status: 200, body: Data(#"{"items": 1}"#.utf8)), on: host)
        await #expect(throws: PublicDataError.invalidData) {
            try await client().checks(slug: "lula")
        }
    }

    @Test func showcaseCoversEverySealAndPeopleWithout() async throws {
        let now = Date(timeIntervalSince1970: 1_792_917_720)
        let data = ShowcasePublicData(scenario: .normal, now: now)
        let lula = try #require(try await data.checks(slug: "lula"))
        let nikolas = try #require(try await data.checks(slug: "nikolas-ferreira"))
        let tabata = try #require(try await data.checks(slug: "tabata-amaral"))
        let verdicts = (lula.items + nikolas.items + tabata.items).map(\.verdict)
        #expect(
            Set(verdicts) == ["Falso", "Enganoso", "Comprovado", "Contextualizando", nil])
        #expect(lula.items.map(\.date) == lula.items.map(\.date).sorted(by: >))
        #expect(lula.sources.map(\.id) == ["comprova"])
        #expect(try await data.checks(slug: "kim-kataguiri") == nil)
        #expect(
            try await ShowcasePublicData(scenario: .empty, now: now).checks(slug: "lula") == nil)
        await #expect(throws: PublicDataError.offline) {
            try await ShowcasePublicData(scenario: .offline, now: now).checks(slug: "lula")
        }
    }
}
