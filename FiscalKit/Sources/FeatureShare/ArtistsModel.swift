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
    public private(set) var lens: Lens?
    public private(set) var shownCollections: [GalleryKind: ArtCollection.ID] = [:]

    @ObservationIgnored private let loader: @Sendable () throws -> ArtCatalog
    @ObservationIgnored private let lensRepository: (any LensRepository)?

    public init(
        lens: (any LensRepository)? = nil,
        loader: @escaping @Sendable () throws -> ArtCatalog = { try ArtCatalog.bundled() }
    ) {
        lensRepository = lens
        self.loader = loader
    }

    public var isEmpty: Bool { catalog?.works.isEmpty ?? true }

    public var workCount: Int { catalog?.works.count ?? 0 }

    public var artistCount: Int { Set(catalog?.works.map(\.artist) ?? []).count }

    public var isAdapted: Bool {
        guard let id = lens?.artCollection else { return false }
        return catalog?.collection(id: id) != nil
    }

    public var showsLensBadge: Bool { isAdapted }

    public var collections: [ArtCollection] {
        guard let catalog else { return [] }
        let chosen = isAdapted ? lens?.artCollection : nil
        return catalog.collections.filter { $0.id == chosen }
            + catalog.collections.filter { $0.id != chosen }
    }

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
        lens = try? await lensRepository?.lens()
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
