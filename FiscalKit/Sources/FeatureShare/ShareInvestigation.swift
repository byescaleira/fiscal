import FeatureCore
import FiscalDomain
import Foundation

public struct ShareInvestigation: Hashable, Sendable {
    public let question: String
    public let conclusion: String
    public let numbers: [SharePoster.Fact]
    public let faces: [ShareFace]
    public let compared: String?
    public let uncertainty: String?

    public static let numberLimit = 3
    public static let faceLimit = 5

    public var texts: [String] {
        [question, conclusion] + numbers.flatMap { [$0.value, $0.label] }
            + faces.flatMap { [$0.name, $0.party] } + [compared, uncertainty].compactMap(\.self)
    }

    public func numbers(for format: ShareFormat) -> [SharePoster.Fact] {
        Array(numbers.prefix(format == .message ? 2 : Self.numberLimit))
    }
}

extension ShareCardContent {
    public var investigation: ShareInvestigation? {
        if case .investigation(let investigation) = body { return investigation }
        return nil
    }

    public var hasOwnPoster: Bool { isVictory || investigation != nil }
}

extension ShareCard {
    public var investigation: ShareInvestigation? { content.investigation }
}

extension ShareCardBuilder {
    public func investigation(_ summary: InvestigationSummary) -> ShareCardContent {
        let faces = summary.faces.prefix(ShareInvestigation.faceLimit).map {
            ShareFace(slug: $0.slug, name: $0.name, party: $0.party, detail: $0.party)
        }
        let body = ShareInvestigation(
            question: summary.question, conclusion: summary.conclusion,
            numbers: summary.numbers.prefix(ShareInvestigation.numberLimit).map {
                SharePoster.Fact(value: $0.value, label: $0.label)
            },
            faces: Array(faces), compared: summary.compared, uncertainty: summary.uncertainty)
        let names =
            summary.sources.isEmpty
            ? PublicFormat.missing : summary.sources.formatted(.list(type: .and).locale(.app))
        let reference = summary.faces.map(\.slug).prefix(2).joined(separator: "+")
        return ShareCardContent(
            eyebrow: eyebrow(
                String(appLocalized: "Investigation"), summary.updatedAt.map(dayMonth) ?? ""),
            headline: summary.question, faces: Array(faces), body: .investigation(body),
            source: sourceLine(name: names, updatedAt: summary.updatedAt),
            stamp: stamp(
                origin: "fiscal", "INV", reference.isEmpty ? "board" : reference,
                summary.updatedAt),
            link: investigationLink(summary.faces.map(\.slug)))
    }

    func dayMonth(_ date: Date) -> String {
        dayMonth(CalendarDay(date, calendar: calendar))
    }

    func investigationLink(_ slugs: [String]) -> URL {
        switch slugs.count {
        case 1: return link("person", slugs[0])
        case 2: return link("compare", slugs.joined(separator: ","))
        default:
            var components = URLComponents()
            components.scheme = "https"
            components.host = Self.host
            components.path = "/"
            return components.url ?? URL(fileURLWithPath: "/")
        }
    }
}
