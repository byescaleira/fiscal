import FiscalDomain
import Foundation

struct PublicDataResolver: Sendable {
    let isPack: Bool
    let fetch: @Sendable (String) async throws -> Data

    init(isPack: Bool = false, fetch: @escaping @Sendable (String) async throws -> Data) {
        self.isPack = isPack
        self.fetch = fetch
    }

    func value<Value: Decodable>(_ path: String) async throws -> Value {
        switch PublicDataLayout.locate(path) {
        case .file(let file):
            return try Self.decode(try await fetch(file), keys: [])
        case .member(let file, let keys):
            return try Self.decode(try await fetch(file), keys: keys)
        case .profile(let slug):
            do {
                return try Self.decode(try await fetch("people/\(slug).json"), keys: ["profile"])
            } catch PublicDataError.notFound {
                return try await cityProfile(slug)
            } catch PublicDataError.offline where isPack {
                do {
                    return try await cityProfile(slug)
                } catch PublicDataError.notFound {
                    throw PublicDataError.offline
                }
            }
        }
    }

    private func cityProfile<Value: Decodable>(_ slug: String) async throws -> Value {
        let index = PublicDataLayout.cityPeopleIndex.path(slug)
        let code: String = try Self.decode(try await fetch(index), keys: ["items", slug])
        let city = try await fetch("places/city/\(code).json")
        return try Self.decode(city, keys: ["people", slug])
    }

    static func decode<Value: Decodable>(_ data: Data, keys: [String]) throws -> Value {
        let value: Value?
        do {
            value = try PublicDataMember<Value>.decode(data, keys: keys)
        } catch {
            throw PublicDataError.invalidData
        }
        guard let value else { throw PublicDataError.notFound }
        return value
    }
}
