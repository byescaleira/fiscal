import Foundation
import SwiftUI

public struct ArtCatalog: Codable, Sendable, Hashable {
    public let collections: [ArtCollection]
    public let works: [ArtWork]
    public let series: [ArtSeries]?

    public init(collections: [ArtCollection], works: [ArtWork], series: [ArtSeries]? = nil) {
        self.collections = collections
        self.works = works
        self.series = series
    }

    public static func bundled() throws -> ArtCatalog {
        guard let url = Bundle.module.url(forResource: "art-credits", withExtension: "json") else {
            throw ArtCatalogError.missingManifest
        }
        return try decode(Data(contentsOf: url))
    }

    public static func decode(_ data: Data) throws -> ArtCatalog {
        try JSONDecoder().decode(ArtCatalog.self, from: data)
    }

    public var assets: Set<String> {
        Set(works.map(\.asset))
    }

    public var featuredCollections: [ArtCollection] {
        collections.filter { !$0.isReserve }
    }

    public func collection(id: ArtCollection.ID) -> ArtCollection? {
        collections.first { $0.id == id }
    }

    public func work(id: ArtWork.ID) -> ArtWork? {
        works.first { $0.id == id }
    }

    public func works(in collectionID: ArtCollection.ID) -> [ArtWork] {
        works.filter { $0.collection == collectionID }
    }

    public func works(inSeries seriesID: ArtSeries.ID) -> [ArtWork] {
        works.filter { $0.series == seriesID }
    }

    public func works(forState uf: String) -> [ArtWork] {
        works.filter { $0.uf == uf.lowercased() }
    }

    public func leadWork(of collection: ArtCollection) -> ArtWork? {
        work(id: collection.leadWork)
    }
}

public enum ArtCatalogError: Error, Equatable {
    case missingManifest
}

public struct ArtCollection: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let name: String
    public let leadWork: ArtWork.ID
    public let palette: [String]
    public let reserve: Bool?

    public init(
        id: String, name: String, leadWork: ArtWork.ID, palette: [String], reserve: Bool? = nil
    ) {
        self.id = id
        self.name = name
        self.leadWork = leadWork
        self.palette = palette
        self.reserve = reserve
    }

    public var isReserve: Bool {
        reserve ?? false
    }
}

public struct ArtSeries: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

public struct ArtWork: Codable, Sendable, Hashable, Identifiable {
    public enum Kind: String, Codable, Sendable {
        case artwork
        case photo
    }

    public let id: String
    public let asset: String
    public let title: String
    public let artist: String
    public let artistLife: String
    public let year: String
    public let collection: ArtCollection.ID
    public let holder: String
    public let sourceUrl: URL
    public let fileUrl: URL
    public let license: String
    public let licenseUrl: URL
    public let credit: String
    public let kind: Kind?
    public let series: ArtSeries.ID?
    public let author: String?
    public let event: String?
    public let uf: String?
    public let place: String?

    public var image: Image {
        Image(asset, bundle: .module)
    }

    public var isPhoto: Bool {
        kind == .photo
    }

    public var lifeSpan: String? {
        artistLife.isEmpty ? nil : artistLife
    }
}
