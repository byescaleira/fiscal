import Foundation

public struct AppReleaseCache: Hashable, Sendable, Codable {
    public var release: AppRelease?
    public var fetchedAt: Date?
    public var simulated: UpdateState?

    public init(release: AppRelease? = nil, fetchedAt: Date? = nil, simulated: UpdateState? = nil) {
        self.release = release
        self.fetchedAt = fetchedAt
        self.simulated = simulated
    }

    public func state(for installed: InstalledApp?, enforces: Bool) -> UpdateState {
        guard enforces else { return simulated ?? .current }
        return remoteState(for: installed)
    }

    public func remoteState(for installed: InstalledApp?) -> UpdateState {
        guard let installed, let release else { return .current }
        return release.state(for: installed)
    }
}

public struct AppReleaseStore: Sendable {
    public static let fileName = "app-release.json"

    public static var enforces: Bool {
        #if DEBUG
            false
        #else
            true
        #endif
    }

    public static let appGroup = "group.com.byescaleira"

    public static var shared: AppReleaseStore {
        let group = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroup)
        return AppReleaseStore(
            directory: group?.appending(path: "fiscal") ?? .applicationSupportDirectory)
    }

    private let fileURL: URL

    public init(directory: URL) {
        fileURL = directory.appending(path: Self.fileName)
    }

    public func read() -> AppReleaseCache {
        guard let data = try? Data(contentsOf: fileURL) else { return AppReleaseCache() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(AppReleaseCache.self, from: data)) ?? AppReleaseCache()
    }

    public func write(_ cache: AppReleaseCache) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(cache).write(to: fileURL, options: .atomic)
    }

    public func state(
        for installed: InstalledApp? = .main, enforces: Bool = AppReleaseStore.enforces
    ) -> UpdateState {
        read().state(for: installed, enforces: enforces)
    }

    public var blocks: Bool { state() == .required }
}
