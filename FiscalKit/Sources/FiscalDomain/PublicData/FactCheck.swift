import Foundation

public struct FactCheck: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let verdict: String?
    public let date: CalendarDay
    public let url: URL
    public let publisher: String
    public let license: String
    public let licenseUrl: URL

    public init(
        id: String, title: String, verdict: String?, date: CalendarDay, url: URL,
        publisher: String, license: String, licenseUrl: URL
    ) {
        self.id = id
        self.title = title
        self.verdict = verdict
        self.date = date
        self.url = url
        self.publisher = publisher
        self.license = license
        self.licenseUrl = licenseUrl
    }
}

public struct FactCheckList: Codable, Hashable, Sendable {
    public let items: [FactCheck]
    public let sources: [Source]

    public init(items: [FactCheck], sources: [Source]) {
        self.items = items
        self.sources = sources
    }
}
