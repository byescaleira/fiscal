import FiscalDomain
import Foundation
import Observation

@MainActor @Observable
public final class DataExportModel {
    public private(set) var archive: DataArchive?
    public var isExporting = false
    public var error: FiscalError?
    @ObservationIgnored private let repositories: Repositories
    @ObservationIgnored private let now: @Sendable () -> Date

    public init(repositories: Repositories, now: @escaping @Sendable () -> Date = { .now }) {
        self.repositories = repositories
        self.now = now
    }

    public func prepare() async {
        do {
            let support = try await repositories.support.support()
            let following = try await repositories.follows.followed()
            let liked = try await repositories.likes?.liked()
            archive = DataArchive(
                exportedAt: now(), support: support, following: following, liked: liked)
            isExporting = true
        } catch {
            self.error = .onFetch
        }
    }

    public func finish(_ result: Result<URL, any Error>) {
        isExporting = false
        if case .failure = result { error = .onSave }
    }
}
