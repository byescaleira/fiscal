import Foundation

public struct MoneyOverview: Codable, Hashable, Sendable {
    public struct CategoryAmount: Codable, Hashable, Sendable {
        public let category: String
        public let cents: Int

        public init(category: String, cents: Int) {
            self.category = category
            self.cents = cents
        }
    }

    public struct Quota: Codable, Hashable, Sendable {
        public let federalDeputiesCents: Int
        public let senatorsCents: Int
        public let byCategory: [CategoryAmount]

        public init(federalDeputiesCents: Int, senatorsCents: Int, byCategory: [CategoryAmount]) {
            self.federalDeputiesCents = federalDeputiesCents
            self.senatorsCents = senatorsCents
            self.byCategory = byCategory
        }
    }

    public struct OfficeSalary: Codable, Hashable, Sendable {
        public let office: Office
        public let monthlyCents: Int
        public let law: String?

        public init(office: Office, monthlyCents: Int, law: String?) {
            self.office = office
            self.monthlyCents = monthlyCents
            self.law = law
        }
    }

    public struct OriginAmount: Codable, Hashable, Sendable {
        public let origin: String
        public let cents: Int

        public init(origin: String, cents: Int) {
            self.origin = origin
            self.cents = cents
        }
    }

    public struct Campaigns: Codable, Hashable, Sendable {
        public let year: Int
        public let revenueCents: Int
        public let expenseCents: Int
        public let byOrigin: [OriginAmount]

        public init(year: Int, revenueCents: Int, expenseCents: Int, byOrigin: [OriginAmount]) {
            self.year = year
            self.revenueCents = revenueCents
            self.expenseCents = expenseCents
            self.byOrigin = byOrigin
        }
    }

    public struct StateAmount: Codable, Hashable, Sendable {
        public let uf: String
        public let cents: Int

        public init(uf: String, cents: Int) {
            self.uf = uf
            self.cents = cents
        }
    }

    public struct Revenue: Codable, Hashable, Sendable {
        public let year: Int
        public let totalCents: Int
        public let byState: [StateAmount]

        public init(year: Int, totalCents: Int, byState: [StateAmount]) {
            self.year = year
            self.totalCents = totalCents
            self.byState = byState
        }
    }

    public let year: Int
    public let quota: Quota
    public let salaries: [OfficeSalary]
    public let campaigns: Campaigns?
    public let revenue: Revenue?
    public let sources: [Source]

    public init(
        year: Int, quota: Quota, salaries: [OfficeSalary], campaigns: Campaigns?,
        revenue: Revenue?, sources: [Source]
    ) {
        self.year = year
        self.quota = quota
        self.salaries = salaries
        self.campaigns = campaigns
        self.revenue = revenue
        self.sources = sources
    }
}
