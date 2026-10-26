import FiscalDomain
import Foundation

struct OfflinePackEntry: Codable, Equatable, Sendable {
    var etag: String?
    var size: Int
    var stored: Int
}

struct OfflinePackManifest: Codable, Equatable, Sendable {
    var release: String?
    var updatedAt: Date?
    var people: [String] = []
    var missing: [String] = []
    var files: [String: OfflinePackEntry] = [:]

    func storedBytes(of paths: some Sequence<String>) -> Int {
        paths.reduce(0) { $0 + (files[$1]?.stored ?? 0) }
    }

    var summary: OfflinePackSummary {
        OfflinePackSummary(
            storedBytes: files.values.reduce(0) { $0 + $1.stored },
            originalBytes: files.values.reduce(0) { $0 + $1.size }, files: files.count,
            people: people.count, updatedAt: updatedAt)
    }
}

public actor OfflinePackStore {
    public static let shared = OfflinePackStore(directory: OfflinePackStore.defaultDirectory)

    public static var defaultDirectory: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appending(path: "OfflinePack", directoryHint: .isDirectory)
    }

    private static let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789-_./")

    private let directory: URL?
    private var loaded: OfflinePackManifest?

    public init(directory: URL?) {
        self.directory = directory
    }

    var manifest: OfflinePackManifest {
        if let loaded { return loaded }
        let read = directory.flatMap { try? Data(contentsOf: $0.appending(path: "manifest.json")) }
            .flatMap { try? PublicDataCoding.decoder().decode(OfflinePackManifest.self, from: $0) }
        let value = read ?? OfflinePackManifest()
        loaded = value
        return value
    }

    public func summary() -> OfflinePackSummary { manifest.summary }

    public var updatedAt: Date? { manifest.updatedAt }

    func entry(for path: String) -> OfflinePackEntry? { manifest.files[path] }

    func hasFile(_ path: String) -> Bool {
        guard manifest.files[path] != nil, let url = Self.fileURL(for: path, in: directory) else {
            return false
        }
        return FileManager.default.fileExists(atPath: url.path())
    }

    public func data(for path: String) -> Data? {
        guard hasFile(path), let url = Self.fileURL(for: path, in: directory),
            let packed = try? Data(contentsOf: url)
        else { return nil }
        return try? Self.decompress(packed)
    }

    func write(_ data: Data, etag: String?, for path: String) throws {
        guard let url = Self.fileURL(for: path, in: directory) else {
            throw PublicDataError.invalidData
        }
        try prepareDirectory()
        let packed = try Self.compress(data)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try packed.write(to: url, options: [.atomic])
        var next = manifest
        next.files[path] = OfflinePackEntry(etag: etag, size: data.count, stored: packed.count)
        try save(next)
    }

    func commit(
        release: String, people: [String], keeping paths: Set<String>, missing: Set<String>,
        at date: Date
    ) throws {
        var next = manifest
        for path in next.files.keys where !paths.contains(path) {
            if let url = Self.fileURL(for: path, in: directory) {
                try? FileManager.default.removeItem(at: url)
            }
            next.files[path] = nil
        }
        next.release = release
        next.people = people
        next.missing = missing.sorted()
        next.updatedAt = date
        try save(next)
    }

    public func erase() {
        if let directory { try? FileManager.default.removeItem(at: directory) }
        loaded = OfflinePackManifest()
    }

    private func save(_ next: OfflinePackManifest) throws {
        loaded = next
        guard let directory else { return }
        try prepareDirectory()
        let data = try PublicDataCoding.encoder().encode(next)
        try data.write(to: directory.appending(path: "manifest.json"), options: [.atomic])
    }

    private func prepareDirectory() throws {
        guard var directory, !FileManager.default.fileExists(atPath: directory.path()) else {
            return
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
    }

    static func isSafe(_ path: String) -> Bool {
        !path.isEmpty && path.allSatisfy(allowed.contains) && !path.contains("..")
            && !path.hasPrefix("/") && path.hasSuffix(".json")
    }

    static func fileURL(for path: String, in directory: URL?) -> URL? {
        guard let directory, isSafe(path) else { return nil }
        return directory.appending(path: "files").appending(path: path + ".lzfse")
    }

    static func compress(_ data: Data) throws -> Data {
        try (data as NSData).compressed(using: .lzfse) as Data
    }

    static func decompress(_ data: Data) throws -> Data {
        try (data as NSData).decompressed(using: .lzfse) as Data
    }
}
