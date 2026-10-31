import FeatureCore
import FiscalDomain
import FiscalResource
import Foundation
import Observation

@MainActor @Observable
final class SettingsLensModel {
    private(set) var catalog: ArtCatalog?
    private(set) var faces: [PersonCard] = []
    @ObservationIgnored private let service: (any PublicDataService)?
    @ObservationIgnored private let loadCatalog: () throws -> ArtCatalog

    init(
        service: (any PublicDataService)?,
        catalog: @escaping () throws -> ArtCatalog = { try ArtCatalog.bundled() }
    ) {
        self.service = service
        loadCatalog = catalog
    }

    func load(_ lens: LensContext?) async {
        await lens?.load()
        if catalog == nil { catalog = try? loadCatalog() }
    }

    func loadFaces(for supported: [String], follows: (any FollowRepository)?) async {
        faces = await SupportedPeople.cards(for: supported, service: service, follows: follows)
    }

    func summary(for lens: Lens?) -> LensSummary {
        LensSummary(lens: lens, catalog: catalog, cards: faces)
    }
}
