import Foundation

public enum AppGroup {
    public static let identifier = "group.com.byescaleira"
    public static let app = "fiscal"
    public static let scheme = "fiscal"

    public static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    public static var defaults: UserDefaults? {
        UserDefaults(suiteName: identifier)
    }

    public static func directory(for app: String = AppGroup.app) -> URL? {
        containerURL.map { directory(for: app, in: $0) }
    }

    public static func directory(for app: String, in container: URL) -> URL {
        let directory = container.appending(path: app, directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    public static func publish(_ manifest: AppGroupManifest, in container: URL? = containerURL)
        throws
    {
        guard let container else { return }
        let url = directory(for: manifest.app, in: container)
            .appending(path: AppGroupManifest.fileName)
        try AppGroupManifest.encoder.encode(manifest).write(to: url, options: .atomic)
    }

    public static func manifests(in container: URL? = containerURL) -> [AppGroupManifest] {
        guard let container,
            let folders = try? FileManager.default.contentsOfDirectory(
                at: container, includingPropertiesForKeys: nil)
        else { return [] }
        return folders.compactMap { folder in
            let url = folder.appending(path: AppGroupManifest.fileName)
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? AppGroupManifest.decoder.decode(AppGroupManifest.self, from: data)
        }
        .sorted { $0.app < $1.app }
    }
}

public struct AppGroupManifest: Codable, Hashable, Sendable {
    public static let fileName = "manifest.json"

    public let app: String
    public let bundle: String
    public let version: String
    public let scheme: String
    public let files: [String]
    public let updatedAt: Date

    public init(
        app: String = AppGroup.app, bundle: String, version: String,
        scheme: String = AppGroup.scheme, files: [String], updatedAt: Date
    ) {
        self.app = app
        self.bundle = bundle
        self.version = version
        self.scheme = scheme
        self.files = files
        self.updatedAt = updatedAt
    }

    public static func current(
        bundle: Bundle = .main, files: [String] = [AppReleaseStore.fileName], now: Date = .now
    ) -> AppGroupManifest {
        AppGroupManifest(
            bundle: bundle.bundleIdentifier ?? "",
            version: InstalledApp(info: bundle.infoDictionary ?? [:])?.description ?? "",
            files: files, updatedAt: now)
    }

    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        return encoder
    }

    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
