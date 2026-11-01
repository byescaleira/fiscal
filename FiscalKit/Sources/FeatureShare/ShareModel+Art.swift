import FiscalDomain
import FiscalResource
import Foundation

extension ShareModel {
    public var isArtAdapted: Bool {
        guard let id = lens?.artCollection else { return false }
        return catalog?.collection(id: id) != nil
    }

    public var showsLensBadge: Bool { isArtAdapted }

    public var collections: [ArtCollection] {
        guard let catalog else { return [] }
        let preferred = preferredCollectionID
        return catalog.collections.filter { $0.id == preferred }
            + catalog.collections.filter { $0.id != preferred }
    }

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
        return catalog.collection(id: preferredCollectionID).flatMap(catalog.leadWork(of:))
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

    private var preferredCollectionID: ArtCollection.ID {
        let ids = catalog?.collections.map(\.id) ?? []
        if ids.contains(Self.neutralCollection) { return Self.neutralCollection }
        if let chosen = lens?.artCollection, ids.contains(chosen) { return chosen }
        return ids.first ?? Self.neutralCollection
    }
}
