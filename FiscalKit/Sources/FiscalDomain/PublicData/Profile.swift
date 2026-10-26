import Foundation

public struct Profile: Codable, Hashable, Identifiable, Sendable {
    public let slug: String
    public let name: String
    public let civilName: String?
    public let office: Office
    public let uf: String
    public let party: String
    public let photo: URL?
    public let status: PersonStatus
    public private(set) var gender: Gender?
    public let mandate: Mandate?
    public let birthDate: CalendarDay?
    public let birthPlace: String?
    public let education: String?
    public let contact: Contact?
    public let salary: Salary?
    public let numbers: Numbers
    public let years: [Year]
    public let themes: [ThemeCount]
    public let committees: [Committee]
    public let assets: [AssetDeclaration]
    public let campaigns: [Campaign]
    public let timeline: [Career]
    public let coverage: [Coverage]
    public let sources: [Source]

    public init(
        card: PersonCard, civilName: String?, mandate: Mandate?, birthDate: CalendarDay?,
        birthPlace: String?, education: String?, contact: Contact?, salary: Salary?,
        numbers: Numbers, history: History, sources: [Source]
    ) {
        slug = card.slug
        name = card.name
        self.civilName = civilName
        office = card.office
        uf = card.uf
        party = card.party
        photo = card.photo
        status = card.status
        gender = card.gender
        self.mandate = mandate
        self.birthDate = birthDate
        self.birthPlace = birthPlace
        self.education = education
        self.contact = contact
        self.salary = salary
        self.numbers = numbers
        years = history.years
        themes = history.themes
        committees = history.committees
        assets = history.assets
        campaigns = history.campaigns
        timeline = history.timeline
        coverage = history.coverage
        self.sources = sources
    }

    public var id: String { slug }

    public var card: PersonCard {
        PersonCard(
            slug: slug, name: name, office: office, uf: uf, party: party, photo: photo,
            status: status, gender: gender)
    }

    public var officeTitle: String { office.title(for: gender) }

    public func with(gender: Gender?) -> Profile {
        var copy = self
        copy.gender = gender
        return copy
    }

    public var history: History {
        History(
            years: years, themes: themes, committees: committees, assets: assets,
            campaigns: campaigns, timeline: timeline, coverage: coverage)
    }

    public func coverage(of kind: String) -> Coverage.Status {
        coverage.first { $0.kind == kind }?.status ?? .notLoaded
    }
}

extension Profile {
    public struct History: Hashable, Sendable {
        public let years: [Year]
        public let themes: [ThemeCount]
        public let committees: [Committee]
        public let assets: [AssetDeclaration]
        public let campaigns: [Campaign]
        public let timeline: [Career]
        public let coverage: [Coverage]

        public init(
            years: [Year] = [], themes: [ThemeCount] = [], committees: [Committee] = [],
            assets: [AssetDeclaration] = [], campaigns: [Campaign] = [], timeline: [Career] = [],
            coverage: [Coverage] = []
        ) {
            self.years = years
            self.themes = themes
            self.committees = committees
            self.assets = assets
            self.campaigns = campaigns
            self.timeline = timeline
            self.coverage = coverage
        }
    }

    public struct Mandate: Codable, Hashable, Sendable {
        public let start: CalendarDay?
        public let end: CalendarDay?

        public init(start: CalendarDay?, end: CalendarDay?) {
            self.start = start
            self.end = end
        }
    }

    public struct Contact: Codable, Hashable, Sendable {
        public let email: String?
        public let phone: String?
        public let office: String?

        public init(email: String?, phone: String?, office: String?) {
            self.email = email
            self.phone = phone
            self.office = office
        }
    }

    public struct Salary: Codable, Hashable, Sendable {
        public let monthlyCents: Int
        public let law: String?

        public init(monthlyCents: Int, law: String?) {
            self.monthlyCents = monthlyCents
            self.law = law
        }
    }

    public struct Attendance: Codable, Hashable, Sendable {
        public let present: Int
        public let eligible: Int

        public init(present: Int, eligible: Int) {
            self.present = present
            self.eligible = eligible
        }

        public var fraction: Double? {
            eligible > 0 ? Double(present) / Double(eligible) : nil
        }
    }

    public struct Numbers: Codable, Hashable, Sendable {
        public let attendance: Attendance?
        public let proposals: Int?
        public let laws: Int?
        public let speeches: Int?
        public let votes: Int?
        public let quotaCents: Int?
        public let assetsCents: Int?
        public let campaignRevenueCents: Int?
        public let lastElectionVotes: Int?

        public init(
            attendance: Attendance?, proposals: Int?, laws: Int?, speeches: Int?, votes: Int?,
            quotaCents: Int?, assetsCents: Int?, campaignRevenueCents: Int?,
            lastElectionVotes: Int?
        ) {
            self.attendance = attendance
            self.proposals = proposals
            self.laws = laws
            self.speeches = speeches
            self.votes = votes
            self.quotaCents = quotaCents
            self.assetsCents = assetsCents
            self.campaignRevenueCents = campaignRevenueCents
            self.lastElectionVotes = lastElectionVotes
        }
    }
}
