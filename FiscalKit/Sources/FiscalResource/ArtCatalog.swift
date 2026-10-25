import Foundation
import SwiftUI

public struct ArtCatalog: Codable, Sendable, Hashable {
    public let collections: [ArtCollection]
    public let works: [ArtWork]

    public init(collections: [ArtCollection], works: [ArtWork]) {
        self.collections = collections
        self.works = works
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

    public func collection(id: ArtCollection.ID) -> ArtCollection? {
        collections.first { $0.id == id }
    }

    public func work(id: ArtWork.ID) -> ArtWork? {
        works.first { $0.id == id }
    }

    public func works(in collectionID: ArtCollection.ID) -> [ArtWork] {
        works.filter { $0.collection == collectionID }
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

    public init(id: String, name: String, leadWork: ArtWork.ID, palette: [String]) {
        self.id = id
        self.name = name
        self.leadWork = leadWork
        self.palette = palette
    }
}

public struct ArtWork: Codable, Sendable, Hashable, Identifiable {
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

    public var image: Image {
        Image(asset, bundle: .module)
    }
}
