import FiscalDomain
import Foundation
import Observation

@MainActor @Observable
final class SourcesModel {
    private(set) var meta: PublicMeta?
    private(set) var method: WeightMethod?
    private(set) var hasLoaded = false
    @ObservationIgnored private let service: (any PublicDataService)?

    init(service: (any PublicDataService)?) {
        self.service = service
    }

    var isAvailable: Bool { service != nil }

    var sources: [Source] {
        var seen = Set<String>()
        let all = (meta?.sources ?? []) + (method?.sources ?? [])
        return all.filter { seen.insert($0.id).inserted }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var updatedText: String? {
        meta.map { String(appLocalized: "Updated \(PublicFormat.updated($0.generatedAt))") }
    }

    var peopleCount: Int? { meta?.counts.people }

    func load() async {
        guard let service, !hasLoaded else { return }
        async let meta = try? service.meta()
        async let method = try? service.weightMethod()
        self.meta = await meta
        self.method = await method ?? nil
        hasLoaded = true
    }
}

extension Source {
    var updatedText: String? {
        updatedAt.map { String(appLocalized: "Updated \(PublicFormat.updated($0))") }
    }
}
