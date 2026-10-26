import Foundation

public enum ShowcaseRosterFile {
    public struct Person: Hashable, Sendable {
        public let slug: String
        public let name: String
        public let office: String
        public let uf: String
        public let party: String
        public let photo: String?
        public let status: String
        public let gender: String?
    }

    public struct Official: Hashable, Sendable {
        public let office: String
        public let name: String
        public let party: String
        public let gender: String?
    }

    public struct City: Hashable, Sendable {
        public let code: String
        public let name: String
        public let uf: String
        public let note: String?
        public let officials: [Official]
    }

    static let offices = ["mayor", "viceMayor", "cityCouncilor"]

    public static var people: [Person] { Storage.people }

    public static var cities: [City] { Storage.cities }

    public static func city(code: String) -> City? { Storage.byCode[code] }

    public static func decodePeople(_ data: Data) -> [Person] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let rows = root["people"] as? [[Any]]
        else { return [] }
        return rows.compactMap { row in
            guard row.count >= 7, let slug = row[0] as? String, let name = row[1] as? String,
                let office = row[2] as? String, let uf = row[3] as? String,
                let party = row[4] as? String, let status = row[6] as? String
            else { return nil }
            return Person(
                slug: slug, name: name, office: office, uf: uf, party: party,
                photo: row[5] as? String, status: status,
                gender: row.count > 7 ? row[7] as? String : nil)
        }
    }

    public static func decodeCities(_ data: Data) -> [City] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let rows = root["cities"] as? [[Any]]
        else { return [] }
        return rows.compactMap { row in
            guard row.count == 5, let code = row[0] as? String, let name = row[1] as? String,
                let uf = row[2] as? String, let list = row[4] as? [[Any]]
            else { return nil }
            let officials = list.compactMap { item -> Official? in
                guard item.count >= 3, let index = item[0] as? Int, offices.indices.contains(index),
                    let person = item[1] as? String, let party = item[2] as? String
                else { return nil }
                return Official(
                    office: offices[index], name: person, party: party,
                    gender: item.count > 3 ? item[3] as? String : nil)
            }
            return City(
                code: code, name: name, uf: uf, note: row[3] as? String, officials: officials)
        }
    }

    private enum Storage {
        static let people = load("showcase-people").map(decodePeople) ?? []
        static let cities = load("showcase-cities").map(decodeCities) ?? []
        static let byCode = Dictionary(
            cities.map { ($0.code, $0) }, uniquingKeysWith: { first, _ in first })

        static func load(_ name: String) -> Data? {
            Bundle.module.url(forResource: name, withExtension: "json").flatMap {
                try? Data(contentsOf: $0)
            }
        }
    }
}
