#if DEBUG
    import FiscalDomain
    import Foundation

    public struct ShowcaseRoster: Sendable {
        public struct City: Hashable, Sendable {
            public let place: Place
            public let officials: [PersonCard]
            public let note: String?

            public init(place: Place, officials: [PersonCard], note: String?) {
                self.place = place
                self.officials = officials
                self.note = note
            }
        }

        let people: @Sendable () -> [PersonCard]
        let places: @Sendable () -> [Place]
        let city: @Sendable (String) -> City?

        public init(
            people: @escaping @Sendable () -> [PersonCard],
            places: @escaping @Sendable () -> [Place],
            city: @escaping @Sendable (String) -> City?
        ) {
            self.people = people
            self.places = places
            self.city = city
        }

        public static let curated = ShowcaseRoster(
            people: { [] }, places: { ShowcaseCities.all.map(\.place) },
            city: { code in ShowcaseCities.all.first { $0.place.code == code } })

        public func official(slug: String) -> PersonCard? {
            guard let code = Self.code(in: slug) else { return nil }
            return city(code)?.officials.first { $0.slug == slug }
        }

        public static func cards(
            _ officials: [(office: Office, name: String, party: String)], in place: Place
        ) -> [PersonCard] {
            var used = Set<String>()
            return officials.map { official in
                let base = "\(slug(official.name))-\(place.code)"
                var slug = base
                var suffix = 2
                while !used.insert(slug).inserted {
                    slug = "\(base)-\(suffix)"
                    suffix += 1
                }
                return PersonCard(
                    slug: slug, name: official.name, office: official.office, uf: place.uf,
                    party: official.party, photo: nil, status: .inOffice)
            }
        }

        static func slug(_ text: String) -> String {
            let folded = text.folding(
                options: [.diacriticInsensitive, .caseInsensitive], locale: nil
            )
            .lowercased()
            return folded.split { !($0.isASCII && ($0.isLetter || $0.isNumber)) }
                .joined(separator: "-")
        }

        static func code(in slug: String) -> String? {
            let parts: [Substring] = slug.split(separator: "-")
            return parts.last { $0.count == 7 && $0.allSatisfy(\.isNumber) }.map(String.init)
        }
    }
#endif
