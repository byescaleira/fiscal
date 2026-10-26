import Foundation

public struct MandateCost: Codable, Hashable, Sendable {
    public enum Role: String, Codable, CaseIterable, Hashable, Sendable {
        case federalDeputy, senator, president, vicePresident, minister

        public var title: String {
            switch self {
            case .federalDeputy: String(appLocalized: "Federal Deputy")
            case .senator: String(appLocalized: "Senator")
            case .president: String(appLocalized: "President")
            case .vicePresident: String(appLocalized: "Vice President")
            case .minister: String(appLocalized: "Minister of State")
            }
        }
    }

    public enum Kind: String, Codable, CaseIterable, Hashable, Sendable {
        case salary, quota, staff, housing

        public var title: String {
            switch self {
            case .salary: String(appLocalized: "Salary")
            case .quota: String(appLocalized: "Office allowance")
            case .staff: String(appLocalized: "Staff budget")
            case .housing: String(appLocalized: "Housing allowance")
            }
        }
    }

    public struct Act: Codable, Hashable, Sendable {
        public let name: String
        public let url: URL?
        public let since: CalendarDay?

        public init(name: String, url: URL?, since: CalendarDay?) {
            self.name = name
            self.url = url
            self.since = since
        }
    }

    public struct StateAmount: Codable, Hashable, Sendable {
        public let uf: String
        public let monthlyCents: Int

        public init(uf: String, monthlyCents: Int) {
            self.uf = uf
            self.monthlyCents = monthlyCents
        }
    }

    public struct Item: Codable, Hashable, Sendable {
        public let kind: Kind
        public let monthlyCents: Int?
        public let byState: [StateAmount]?
        public let act: Act

        public init(kind: Kind, monthlyCents: Int?, byState: [StateAmount]?, act: Act) {
            self.kind = kind
            self.monthlyCents = monthlyCents
            self.byState = byState
            self.act = act
        }

        public func cents(uf: String) -> Int? {
            if let monthlyCents { return monthlyCents }
            return byState?.first { $0.uf.lowercased() == uf.lowercased() }?.monthlyCents
        }
    }

    public struct RoleCost: Codable, Hashable, Sendable {
        public let role: Role
        public let items: [Item]
        public let unpublished: [Kind]

        public init(role: Role, items: [Item], unpublished: [Kind]) {
            self.role = role
            self.items = items
            self.unpublished = unpublished
        }
    }

    public struct Reference: Codable, Hashable, Sendable {
        public let monthlyCents: Int
        public let period: String?
        public let act: Act

        public init(monthlyCents: Int, period: String?, act: Act) {
            self.monthlyCents = monthlyCents
            self.period = period
            self.act = act
        }
    }

    public let checkedAt: CalendarDay
    public let roles: [RoleCost]
    public let minimumWage: Reference?
    public let laborIncome: Reference?
    public let sources: [Source]

    public init(
        checkedAt: CalendarDay, roles: [RoleCost], minimumWage: Reference?,
        laborIncome: Reference?, sources: [Source]
    ) {
        self.checkedAt = checkedAt
        self.roles = roles
        self.minimumWage = minimumWage
        self.laborIncome = laborIncome
        self.sources = sources
    }
}
