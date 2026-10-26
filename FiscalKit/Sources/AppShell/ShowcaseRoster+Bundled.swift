#if DEBUG
    import FiscalData
    import FiscalDomain
    import FiscalResource
    import Foundation

    extension ShowcaseRoster {
        public static let bundled = ShowcaseRoster(
            people: { Bundled.people }, places: { Bundled.places },
            city: { code in ShowcaseRosterFile.city(code: code).map(city) },
            document: { ShowcaseArchive.document($0) })

        private enum Bundled {
            static let people = ShowcaseRosterFile.people.compactMap(card)
            static let places = ShowcaseRosterFile.cities.map(place)
        }

        static func card(_ person: ShowcaseRosterFile.Person) -> PersonCard? {
            guard let office = Office(rawValue: person.office),
                let status = PersonStatus(rawValue: person.status)
            else { return nil }
            return PersonCard(
                slug: person.slug, name: person.name, office: office, uf: person.uf,
                party: person.party, photo: person.photo.flatMap(URL.init(string:)),
                status: status, gender: person.gender.flatMap(Gender.init(rawValue:)))
        }

        static func place(_ city: ShowcaseRosterFile.City) -> Place {
            Place(code: city.code, name: city.name, uf: city.uf)
        }

        static func city(_ city: ShowcaseRosterFile.City) -> ShowcaseRoster.City {
            let place = place(city)
            let known = city.officials.filter { Office(rawValue: $0.office) != nil }
            let officials = known.compactMap { official in
                Office(rawValue: official.office).map { ($0, official.name, official.party) }
            }
            let genders = known.map { $0.gender.flatMap(Gender.init(rawValue:)) }
            return ShowcaseRoster.City(
                place: place, officials: cards(officials, in: place, genders: genders),
                note: city.note)
        }
    }
#endif
