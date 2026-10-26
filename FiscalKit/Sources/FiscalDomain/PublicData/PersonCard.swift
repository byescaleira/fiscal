import Foundation

public struct PersonCard: Codable, Hashable, Identifiable, Sendable {
    public let slug: String
    public let name: String
    public let office: Office
    public let uf: String
    public let party: String
    public let photo: URL?
    public let status: PersonStatus
    public let gender: Gender?

    public init(
        slug: String, name: String, office: Office, uf: String, party: String, photo: URL?,
        status: PersonStatus, gender: Gender? = nil
    ) {
        self.slug = slug
        self.name = name
        self.office = office
        self.uf = uf
        self.party = party
        self.photo = photo
        self.status = status
        self.gender = gender
    }

    public var id: String { slug }

    public var officeTitle: String { office.title(for: gender) }

    public func with(gender: Gender?) -> PersonCard {
        PersonCard(
            slug: slug, name: name, office: office, uf: uf, party: party, photo: photo,
            status: status, gender: gender)
    }
}

public struct RepresentativeGroup: Codable, Hashable, Sendable {
    public enum Level: String, Codable, Sendable {
        case country, state, city
    }

    public let level: Level
    public let office: Office
    public let title: String
    public let people: [PersonCard]

    public init(level: Level, office: Office, title: String, people: [PersonCard]) {
        self.level = level
        self.office = office
        self.title = title
        self.people = people
    }
}

public struct PlaceRepresentatives: Codable, Hashable, Sendable {
    public let code: String?
    public let uf: String
    public let name: String
    public let groups: [RepresentativeGroup]
    public let note: String?
    public let sources: [Source]

    public init(
        code: String? = nil, uf: String, name: String, groups: [RepresentativeGroup],
        note: String? = nil, sources: [Source]
    ) {
        self.code = code
        self.uf = uf
        self.name = name
        self.groups = groups
        self.note = note
        self.sources = sources
    }
}

public struct Place: Codable, Hashable, Identifiable, Sendable {
    public let code: String
    public let name: String
    public let uf: String

    public init(code: String, name: String, uf: String) {
        self.code = code
        self.name = name
        self.uf = uf
    }

    public var id: String { code }

    public var isState: Bool { code == uf }
}

public struct PublicMeta: Codable, Hashable, Sendable {
    public struct Counts: Codable, Hashable, Sendable {
        public let people: Int
        public let federal: Int
        public let state: Int
        public let places: Int

        public init(people: Int, federal: Int, state: Int, places: Int) {
            self.people = people
            self.federal = federal
            self.state = state
            self.places = places
        }
    }

    public let generatedAt: Date
    public let sources: [Source]
    public let counts: Counts

    public init(generatedAt: Date, sources: [Source], counts: Counts) {
        self.generatedAt = generatedAt
        self.sources = sources
        self.counts = counts
    }
}
