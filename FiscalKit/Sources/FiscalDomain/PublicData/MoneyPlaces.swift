import Foundation

public struct MoneyPlaces: Codable, Hashable, Sendable {
    public static let country = "br"

    public struct Spender: Codable, Hashable, Identifiable, Sendable {
        public let person: PersonCard
        public let house: String
        public let monthlyCents: Int
        public let medianCents: Int
        public let p75Cents: Int
        public let band: PeerClassification.Band
        public let topCategory: String?
        public let topCategoryCents: Int?

        public init(
            person: PersonCard, house: String, monthlyCents: Int, medianCents: Int,
            p75Cents: Int, band: PeerClassification.Band, topCategory: String?,
            topCategoryCents: Int?
        ) {
            self.person = person
            self.house = house
            self.monthlyCents = monthlyCents
            self.medianCents = medianCents
            self.p75Cents = p75Cents
            self.band = band
            self.topCategory = topCategory
            self.topCategoryCents = topCategoryCents
        }

        public var id: String { person.slug }
    }

    public struct Quota: Codable, Hashable, Sendable {
        public let totalCents: Int
        public let people: Int
        public let classified: Int
        public let byCategory: [MoneyOverview.CategoryAmount]
        public let spenders: [Spender]

        public init(
            totalCents: Int, people: Int, classified: Int,
            byCategory: [MoneyOverview.CategoryAmount], spenders: [Spender]
        ) {
            self.totalCents = totalCents
            self.people = people
            self.classified = classified
            self.byCategory = byCategory
            self.spenders = spenders
        }
    }

    public struct Campaigns: Codable, Hashable, Sendable {
        public let years: [Int]
        public let revenueCents: Int
        public let people: Int

        public init(years: [Int], revenueCents: Int, people: Int) {
            self.years = years
            self.revenueCents = revenueCents
            self.people = people
        }
    }

    public struct Place: Codable, Hashable, Identifiable, Sendable {
        public let uf: String
        public let deputies: Int
        public let senators: Int
        public let ceilingMonthlyCents: Int?
        public let quota: Quota
        public let campaigns: Campaigns?

        public init(
            uf: String, deputies: Int, senators: Int, ceilingMonthlyCents: Int?,
            quota: Quota, campaigns: Campaigns?
        ) {
            self.uf = uf
            self.deputies = deputies
            self.senators = senators
            self.ceilingMonthlyCents = ceilingMonthlyCents
            self.quota = quota
            self.campaigns = campaigns
        }

        public var id: String { uf }
        public var isCountry: Bool { uf == MoneyPlaces.country }
        public var seats: Int { deputies + senators }
    }

    public let year: Int
    public let places: [Place]
    public let sources: [Source]

    public init(year: Int, places: [Place], sources: [Source]) {
        self.year = year
        self.places = places
        self.sources = sources
    }

    public func place(_ uf: String) -> Place? {
        places.first { $0.uf == uf.lowercased() }
    }
}
