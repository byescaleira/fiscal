import FiscalDomain
import Foundation
import Testing

@testable import FeatureCore

struct EventLogPrivacyTests {
    private static let personal = [
        "nikolas-ferreira", "tabata-amaral", "3550308", "SP", "sp", "Lula", "Bolsonaro",
        "aborto", "PT", "PL",
    ]

    static let samples: [FiscalEvents] =
        [.launch, .dataLoaded, .networkError(status: 403), .offlinePack(files: 12), .alertReceived]
        + FiscalEvents.DeepLinkKind.allCases.map(FiscalEvents.deepLink)

    private static func index(of event: FiscalEvents) -> Int {
        switch event {
        case .launch: 0
        case .dataLoaded: 1
        case .networkError: 2
        case .offlinePack: 3
        case .alertReceived: 4
        case .deepLink: 5
        }
    }

    @Test func samplesCoverEveryEvent() {
        #expect(Set(Self.samples.map(Self.index)) == Set(0...5))
    }

    @Test(arguments: EventLogPrivacyTests.samples)
    func sentenceIsFixedEnglishWithOnlyNumbersOrKinds(_ event: FiscalEvents) {
        let text = event.message.text
        let template = text.filter { !$0.isNumber }
        let allowed = CharacterSet.letters.union(.whitespaces).union(
            CharacterSet(charactersIn: ",:"))
        #expect(template.unicodeScalars.allSatisfy(allowed.contains))
        #expect(template.allSatisfy { $0.isASCII })
        for word in Self.personal {
            #expect(
                !text.split(separator: " ").contains {
                    $0.trimmingCharacters(in: .punctuationCharacters) == word
                })
        }
    }

    @Test func keepsOnlyTheRouteKindOfADeepLink() {
        for kind in FiscalEvents.DeepLinkKind.allCases {
            #expect(
                FiscalEvents.deepLink(kind).message.text == "Deep link opened: \(kind.rawValue)")
        }
    }

    @Test func networkErrorsKeepOnlyTheStatusCode() {
        #expect(
            FiscalEvents.networkError(for: PublicDataError.rejected(403))
                == .networkError(status: 403))
        #expect(FiscalEvents.networkError(for: PublicDataError.offline) == nil)
        #expect(FiscalEvents.networkError(for: PublicDataError.notFound) == nil)
        #expect(FiscalEvents.networkError(for: CancellationError()) == nil)
        #expect(
            FiscalEvents.networkError(status: 503).message.text
                == "Network error, HTTP status 503")
        #expect(
            FiscalEvents.offlinePack(files: 12).message.text
                == "Offline pack refreshed, 12 files")
    }

    @Test func logsTheCategoryAndTheLevel() throws {
        let log = EventLog(subsystem: "EventLogPrivacyTests", capacity: Self.samples.count)
        for event in Self.samples { event.log(to: log) }
        #expect(log.entries.count == Self.samples.count)
        #expect(log.entries.map(\.message) == Self.samples.map(\.message.text))
        #expect(log.entries.map(\.category) == Self.samples.map(\.category.name))
        let error = try #require(log.entries.first { $0.category == "data" && $0.level == .error })
        #expect(error.message == "Network error, HTTP status 403")
        #expect(
            Set(log.entries.map(\.category)) == ["app", "data", "offline", "alerts", "navigation"])
    }
}
