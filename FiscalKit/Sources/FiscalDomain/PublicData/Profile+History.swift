import Foundation

extension Profile {
    public struct Year: Codable, Hashable, Identifiable, Sendable {
        public let year: Int
        public let present: Int?
        public let eligible: Int?
        public let proposals: Int?
        public let laws: Int?
        public let speeches: Int?
        public let votes: Int?
        public let quotaCents: Int?

        public init(
            year: Int, present: Int?, eligible: Int?, proposals: Int?, laws: Int?,
            speeches: Int?, votes: Int?, quotaCents: Int?
        ) {
            self.year = year
            self.present = present
            self.eligible = eligible
            self.proposals = proposals
            self.laws = laws
            self.speeches = speeches
            self.votes = votes
            self.quotaCents = quotaCents
        }

        public var id: Int { year }
    }

    public struct ThemeCount: Codable, Hashable, Identifiable, Sendable {
        public let key: Theme
        public let proposals: Int
        public let speeches: Int

        public init(key: Theme, proposals: Int, speeches: Int) {
            self.key = key
            self.proposals = proposals
            self.speeches = speeches
        }

        public var id: Theme { key }
    }

    public struct Committee: Codable, Hashable, Sendable {
        public let name: String
        public let role: String?
        public let start: CalendarDay?
        public let end: CalendarDay?

        public init(name: String, role: String?, start: CalendarDay?, end: CalendarDay?) {
            self.name = name
            self.role = role
            self.start = start
            self.end = end
        }
    }

    public struct AssetDeclaration: Codable, Hashable, Identifiable, Sendable {
        public struct Item: Codable, Hashable, Sendable {
            public let kind: String
            public let cents: Int

            public init(kind: String, cents: Int) {
                self.kind = kind
                self.cents = cents
            }
        }

        public let year: Int
        public let totalCents: Int
        public let items: [Item]

        public init(year: Int, totalCents: Int, items: [Item]) {
            self.year = year
            self.totalCents = totalCents
            self.items = items
        }

        public var id: Int { year }
    }

    public struct Campaign: Codable, Hashable, Sendable {
        public let year: Int
        public let office: String
        public let result: String?
        public let revenueCents: Int?
        public let expenseCents: Int?

        public init(
            year: Int, office: String, result: String?, revenueCents: Int?, expenseCents: Int?
        ) {
            self.year = year
            self.office = office
            self.result = result
            self.revenueCents = revenueCents
            self.expenseCents = expenseCents
        }
    }

    public struct Career: Codable, Hashable, Sendable {
        public let year: Int
        public let office: String
        public let place: String
        public let party: String
        public let result: String?
        public let votes: Int?

        public init(
            year: Int, office: String, place: String, party: String, result: String?, votes: Int?
        ) {
            self.year = year
            self.office = office
            self.place = place
            self.party = party
            self.result = result
            self.votes = votes
        }
    }

    public struct Coverage: Codable, Hashable, Sendable {
        public enum Status: String, Codable, Sendable {
            case available, notPublished, notLoaded
        }

        public let kind: String
        public let status: Status
        public let source: String?

        public init(kind: String, status: Status, source: String?) {
            self.kind = kind
            self.status = status
            self.source = source
        }
    }
}
