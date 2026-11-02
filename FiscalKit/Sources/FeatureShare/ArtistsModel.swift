import FeatureCore
import FiscalDomain
import FiscalResource
import Foundation
import Observation

public struct GallerySection: Hashable, Identifiable, Sendable {
    public let collection: ArtCollection
    public let works: [ArtWork]

    public var id: String { collection.id }
}

public enum GalleryKind: Hashable, Sendable {
    case openLicense, historical
}

@MainActor @Observable
public final class ArtistsModel {
    public private(set) var hasLoaded = false
    public private(set) var catalog: ArtCatalog?
    public private(set) var shownCollections: [GalleryKind: ArtCollection.ID] = [:]

    @ObservationIgnored private let loader: @Sendable () throws -> ArtCatalog

    public init(
        loader: @escaping @Sendable () throws -> ArtCatalog = { try ArtCatalog.bundled() }
    ) {
        self.loader = loader
    }

    public var isEmpty: Bool { catalog?.works.isEmpty ?? true }

    public var workCount: Int { catalog?.works.count ?? 0 }

    public var artistCount: Int { Set(catalog?.works.map(\.artist) ?? []).count }

    public var collections: [ArtCollection] { catalog?.collections ?? [] }

    public var openLicense: [GallerySection] { sections { !$0.isPublicDomain } }

    public var historical: [GallerySection] { sections(where: \.isPublicDomain) }

    public func sections(on shelf: GalleryKind) -> [GallerySection] {
        switch shelf {
        case .openLicense: openLicense
        case .historical: historical
        }
    }

    public func current(on shelf: GalleryKind) -> GallerySection? {
        let sections = sections(on: shelf)
        return sections.first { $0.id == shownCollections[shelf] } ?? sections.first
    }

    public func show(_ collection: ArtCollection.ID, on shelf: GalleryKind) {
        shownCollections[shelf] = collection
    }

    public func load() async {
        catalog = try? loader()
        hasLoaded = true
    }

    private func sections(where include: (ArtWork) -> Bool) -> [GallerySection] {
        guard let catalog else { return [] }
        return collections.compactMap { collection in
            let works = catalog.works(in: collection.id).filter(include)
            return works.isEmpty ? nil : GallerySection(collection: collection, works: works)
        }
    }
}

extension ArtWork {
    var imageLabel: String {
        [title, artist, lifeSpan].compactMap(\.self).joined(separator: ", ")
    }
}
