import Foundation

public struct AgendaItem: Codable, Hashable, Sendable {
    public let proposition: String
    public let summary: String
    public let status: String?
    public let themes: [Theme]
    public let url: URL?

    public init(
        proposition: String, summary: String, status: String?, themes: [Theme], url: URL?
    ) {
        self.proposition = proposition
        self.summary = summary
        self.status = status
        self.themes = themes
        self.url = url
    }
}

public struct Agenda: Codable, Hashable, Sendable {
    public struct HouseDay: Codable, Hashable, Identifiable, Sendable {
        public let house: House
        public let inSession: Bool
        public let nextSession: Date?
        public let items: [AgendaItem]

        public init(house: House, inSession: Bool, nextSession: Date?, items: [AgendaItem]) {
            self.house = house
            self.inSession = inSession
            self.nextSession = nextSession
            self.items = items
        }

        public var id: House { house }
    }

    public let date: CalendarDay
    public let houses: [HouseDay]

    public init(date: CalendarDay, houses: [HouseDay]) {
        self.date = date
        self.houses = houses
    }
}
