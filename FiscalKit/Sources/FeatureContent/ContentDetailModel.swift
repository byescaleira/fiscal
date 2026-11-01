import FeatureCore
import FiscalDomain
import Foundation
import Observation

@MainActor @Observable
public final class ContentDetailModel {
    public struct Fact: Identifiable, Equatable, Sendable {
        public let title: String
        public let value: String
        public let symbol: String

        public var id: String { title }
    }

    public private(set) var content: ContentDetail?
    public private(set) var phase: PublicDataPhase
    @ObservationIgnored private let highlightID: String?
    @ObservationIgnored private let service: (any PublicDataService)?
    @ObservationIgnored private let requests = PublicDataRequests()

    public init(content: ContentDetail) {
        self.content = content
        phase = .loaded
        highlightID = nil
        service = nil
    }

    public init(highlightID: String, service: (any PublicDataService)?) {
        content = nil
        phase = .idle
        self.highlightID = highlightID
        self.service = service
    }

    public func load() async {
        guard let highlightID, content == nil else { return }
        phase = .loading
        phase = await PublicDataPhase.settle(after: phase, in: requests) { [service] in
            guard let service else { throw PublicDataError.unavailable }
            return try await service.highlights()
        } apply: { [weak self] list in
            guard let list, let item = list.items.first(where: { $0.id == highlightID }) else {
                return
            }
            self?.content = ContentDetail(
                highlight: item, method: list.method,
                sourceLine: SourceFootnote.text(list.sources), shareHighlightID: item.id)
        }
    }

    public var isEmpty: Bool { content == nil }

    public var kicker: String {
        content?.kind.title.uppercased(with: .app) ?? ""
    }

    public var facts: [Fact] {
        guard let content else { return [] }
        var facts: [Fact] = []
        if let stage = content.stage {
            facts.append(Fact(title: String(appLocalized: "Stage"), value: stage, symbol: "flag"))
        }
        if let reference = content.reference {
            facts.append(
                Fact(
                    title: String(appLocalized: "Reference"), value: reference, symbol: "number"))
        }
        if let weight = content.weight {
            facts.append(
                Fact(
                    title: String(appLocalized: "Weight"),
                    value: Relevance(weight: weight).title, symbol: "chart.bar"))
        }
        if let date = content.date {
            facts.append(
                Fact(
                    title: String(appLocalized: "Date"), value: SourceFootnote.day(date),
                    symbol: "calendar"))
        }
        return facts
    }

    public var factRows: [[Fact]] {
        stride(from: 0, to: facts.count, by: 2).map { start in
            Array(facts[start..<min(start + 2, facts.count)])
        }
    }

    public var authorRoute: Route? {
        content?.person.map { .person(slug: $0.slug) }
    }

    public var shareRoute: Route? {
        content?.shareHighlightID.map { .share(.highlight(id: $0)) }
    }
}
