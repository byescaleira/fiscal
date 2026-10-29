import FiscalDomain
import Foundation
import Observation

@MainActor @Observable
public final class SourcesModel {
    public private(set) var meta: PublicMeta?
    public private(set) var method: WeightMethod?
    public private(set) var hasLoaded = false
    public var isShowingMethod = false
    @ObservationIgnored private let service: (any PublicDataService)?

    public init(service: (any PublicDataService)?) {
        self.service = service
    }

    public var isAvailable: Bool { service != nil }

    public var sources: [Source] {
        var seen = Set<String>()
        let all = (meta?.sources ?? []) + (method?.sources ?? [])
        return all.filter { seen.insert($0.id).inserted }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    public var countText: String? {
        let count = sources.count
        return count == 0 ? nil : PublicFormat.number(count)
    }

    public var updatedText: String? {
        meta.map { String(appLocalized: "Updated \(PublicFormat.updated($0.generatedAt))") }
    }

    public var peopleCount: Int? { meta?.counts.people }

    public func load() async {
        guard let service, !hasLoaded else { return }
        async let meta = try? service.meta()
        async let method = try? service.weightMethod()
        self.meta = await meta
        self.method = await method ?? nil
        hasLoaded = true
    }

    public func showMethod() {
        guard method != nil else { return }
        isShowingMethod = true
    }
}

extension Source {
    var updatedText: String? {
        updatedAt.map { String(appLocalized: "Updated \(PublicFormat.updated($0))") }
    }
}
