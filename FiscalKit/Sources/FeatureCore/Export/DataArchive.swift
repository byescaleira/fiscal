import CoreTransferable
import FiscalDomain
import Foundation
import UniformTypeIdentifiers

public struct DataArchive: Codable, Equatable, Sendable, Transferable {
    public let exportedAt: Date
    public let support: SupportChoice?
    public let following: [FollowedPerson]
    public let liked: [LikedItem]?

    public init(
        exportedAt: Date, support: SupportChoice?, following: [FollowedPerson],
        liked: [LikedItem]? = nil
    ) {
        self.exportedAt = exportedAt
        self.support = support
        self.following = following
        self.liked = liked
    }

    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { try $0.encoded() }
    }

    public var fileName: String {
        "Fiscal \(exportedAt.formatted(.iso8601.year().month().day()))"
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    public static func decoded(from data: Data) throws -> DataArchive {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(DataArchive.self, from: data)
    }
}
