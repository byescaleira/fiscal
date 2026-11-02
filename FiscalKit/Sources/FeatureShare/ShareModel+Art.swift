import FiscalDomain
import FiscalResource
import Foundation

extension ShareModel {
    public var collections: [ArtCollection] { catalog?.collections ?? [] }

    public var works: [ArtWork] {
        guard let catalog else { return [] }
        return collections.flatMap { collection in
            let works = catalog.works(in: collection.id)
            return works.filter { $0.series != Self.lastSeries }
                + works.filter { $0.series == Self.lastSeries }
        }
    }

    public var artwork: ShareArtwork? {
        guard let catalog, let work = selectedWork else { return nil }
        return ShareArtwork(
            work: work, palette: catalog.collection(id: work.collection)?.palette ?? [])
    }

    public var selectedWork: ArtWork? {
        guard let catalog else { return nil }
        if let selectedWorkID, let work = catalog.work(id: selectedWorkID) { return work }
        return catalog.collection(id: Self.defaultCollection).flatMap(catalog.leadWork(of:))
            ?? catalog.works.first
    }

    public var currentCollectionID: ArtCollection.ID? {
        collectionID ?? selectedWork?.collection ?? collections.first?.id
    }

    public var currentWorks: [ArtWork] {
        let current = currentCollectionID
        return works.filter { $0.collection == current }
    }

    public var selectedCredit: String? {
        selectedWork.map { "\($0.artist) · \($0.title), \($0.year) · \($0.licenseLabel)" }
    }

    public func isSelected(_ work: ArtWork) -> Bool {
        selectedWork?.id == work.id
    }

    public func select(_ work: ArtWork) {
        selectedWorkID = work.id
    }

    public func show(_ collection: ArtCollection.ID) {
        collectionID = collection
    }
}
