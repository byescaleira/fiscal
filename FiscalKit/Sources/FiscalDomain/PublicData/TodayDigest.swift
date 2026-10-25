import Foundation

public struct TodayDigest: Codable, Hashable, Sendable {
    public struct Event: Codable, Hashable, Sendable {
        public enum Kind: String, Codable, Sendable {
            case vote, session, race, law
        }

        public let kind: Kind
        public let title: String
        public let summary: String
        public let themes: [Theme]
        public let ref: String?

        public init(kind: Kind, title: String, summary: String, themes: [Theme], ref: String?) {
            self.kind = kind
            self.title = title
            self.summary = summary
            self.themes = themes
            self.ref = ref
        }
    }

    public let date: CalendarDay
    public let events: [Event]
    public let sources: [Source]

    public init(date: CalendarDay, events: [Event], sources: [Source]) {
        self.date = date
        self.events = events
        self.sources = sources
    }
}
