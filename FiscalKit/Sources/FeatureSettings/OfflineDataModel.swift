import FiscalDomain
import Foundation
import Observation

@MainActor @Observable
public final class OfflineDataModel {
    public private(set) var summary: OfflinePackSummary = .empty
    public private(set) var isRefreshing = false
    public private(set) var error: PublicDataError?
    @ObservationIgnored private let service: any OfflinePackService

    public init(service: any OfflinePackService) {
        self.service = service
    }

    public func load() async {
        summary = await service.summary()
    }

    public func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            summary = try await service.refresh()
            error = nil
        } catch is CancellationError {
        } catch {
            self.error = error as? PublicDataError ?? .unavailable
            summary = await service.summary()
        }
    }

    public func erase() async {
        summary = await service.erase()
        error = nil
    }

    public var sizeText: String { Self.bytes(summary.storedBytes) }

    public var limitText: String { Self.bytes(OfflinePackSummary.limitBytes) }

    public var fillFraction: Double {
        let limit = Double(OfflinePackSummary.limitBytes)
        guard limit > 0 else { return 0 }
        return min(Double(summary.storedBytes), limit) / limit
    }

    public var originalText: String { Self.bytes(summary.originalBytes) }

    public var updatedText: String? {
        summary.updatedAt.map { PublicFormat.updated($0) }
    }

    static func bytes(_ value: Int) -> String {
        Int64(value).formatted(.byteCount(style: .file).locale(.app))
    }
}
