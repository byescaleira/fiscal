import Foundation

public struct ShowcaseArchive: Sendable {
    public enum Pack: String, CaseIterable, Sendable {
        case core, votes, people
    }

    private let documents: [String: Data]

    public init(documents: [String: Data]) {
        self.documents = documents
    }

    public static let empty = ShowcaseArchive(documents: [:])

    public var paths: [String] { documents.keys.sorted() }

    public func document(_ path: String) -> Data? { documents[path] }

    public static func pack(for path: String) -> Pack {
        switch path.split(separator: "/").first {
        case "votes": .votes
        case "people": .people
        default: .core
        }
    }

    public static func document(_ path: String) -> Data? {
        switch pack(for: path) {
        case .core: Storage.core.document(path)
        case .votes: Storage.votes.document(path)
        case .people: Storage.people.document(path)
        }
    }

    public static func decode(_ data: Data) throws -> ShowcaseArchive {
        guard data.count >= 4 else { throw ShowcaseArchiveError.malformed }
        let length = data.prefix(4).reduce(0) { $0 << 8 | Int($1) }
        let start = data.startIndex + 4
        guard length > 0, data.count >= 4 + length,
            let index = try JSONSerialization.jsonObject(
                with: data.subdata(in: start..<start + length)) as? [String: [Int]]
        else { throw ShowcaseArchiveError.malformed }
        let blob = start + length
        var documents: [String: Data] = [:]
        documents.reserveCapacity(index.count)
        for (path, span) in index {
            guard span.count == 2, span[0] >= 0, span[1] >= 0,
                blob + span[0] + span[1] <= data.endIndex
            else { throw ShowcaseArchiveError.malformed }
            documents[path] = data.subdata(in: blob + span[0]..<blob + span[0] + span[1])
        }
        return ShowcaseArchive(documents: documents)
    }

    static func bundled(_ pack: Pack) -> ShowcaseArchive {
        guard
            let url = Bundle.module.url(
                forResource: "showcase-\(pack.rawValue)", withExtension: "deflate"),
            let packed = try? Data(contentsOf: url),
            let data = try? (packed as NSData).decompressed(using: .zlib) as Data,
            let archive = try? decode(data)
        else { return .empty }
        return archive
    }

    private enum Storage {
        static let core = bundled(.core)
        static let votes = bundled(.votes)
        static let people = bundled(.people)
    }
}

public enum ShowcaseArchiveError: Error, Equatable {
    case malformed
}
