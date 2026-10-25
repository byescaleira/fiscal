import Foundation

public struct RepresentativesDigest: Hashable, Sendable {
    public static let featuredOffices: [Office] = [
        .governor, .senator, .federalDeputy, .stateDeputy,
    ]
    public static let featuredLimit = 4

    public let uf: String
    public let name: String
    public let featured: [PersonCard]
    public let federalDeputies: Int?
    public let stateDeputies: Int?
    public let source: Source?

    public init(_ place: PlaceRepresentatives) {
        uf = place.uf.lowercased()
        name = place.name.isEmpty ? HomePlace.name(of: place.uf.lowercased()) : place.name
        let people = place.groups.flatMap(\.people)
        let ordered = Self.featuredOffices.flatMap { office in
            people.filter { $0.office == office }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
        var seen = Set<String>()
        featured = Array(
            ordered.filter { seen.insert($0.slug).inserted }.prefix(Self.featuredLimit))
        federalDeputies = Self.count(.federalDeputy, in: place.groups)
        stateDeputies = Self.count(.stateDeputy, in: place.groups)
        source = place.sources.first
    }

    private static func count(_ office: Office, in groups: [RepresentativeGroup]) -> Int? {
        let matching = groups.filter { $0.office == office }
        guard !matching.isEmpty else { return nil }
        return Set(matching.flatMap(\.people).map(\.slug)).count
    }

    public var ufText: String { uf.uppercased(with: .app) }

    public var isEmpty: Bool { featured.isEmpty && federalDeputies == nil && stateDeputies == nil }

    public var sourceText: String {
        guard let source else { return String(appLocalized: "Source: \(PublicFormat.missing)") }
        return IntegrationText.updated(source.name, source.updatedAt)
    }

    public func detail(for person: PersonCard) -> String {
        "\(person.office.title) · \(person.party)"
    }

    public func accessibility(for person: PersonCard) -> String {
        "\(person.name), \(person.office.title), \(person.party), \(ufText)"
    }

    public var url: URL? { IntegrationLink.mine }
}
