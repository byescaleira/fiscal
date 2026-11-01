import Foundation

public struct FollowingSnapshot: Codable, Hashable, Sendable {
    public static let fileName = "following.json"
    public static let limit = 6

    public struct Entry: Codable, Hashable, Identifiable, Sendable {
        public let person: PersonCard
        public let latest: FollowingUpdate?

        public var id: String { person.slug }

        public init(person: PersonCard, latest: FollowingUpdate?) {
            self.person = person
            self.latest = latest
        }
    }

    public let entries: [Entry]
    public let updatedAt: Date

    public init(entries: [Entry], updatedAt: Date) {
        self.entries = entries
        self.updatedAt = updatedAt
    }

    public static func make(
        followed: [PersonCard], updates: [FollowingUpdate], at date: Date
    ) -> FollowingSnapshot {
        let latest = Dictionary(grouping: updates, by: \.person.slug).compactMapValues {
            $0.max { $0.day < $1.day }
        }
        let entries = followed.map { Entry(person: $0, latest: latest[$0.slug]) }
            .sorted { lhs, rhs in
                switch (lhs.latest?.day, rhs.latest?.day) {
                case (let left?, let right?) where left != right: left > right
                case (.some, nil): true
                case (nil, .some): false
                default:
                    lhs.person.name.localizedStandardCompare(rhs.person.name) == .orderedAscending
                }
            }
        return FollowingSnapshot(entries: Array(entries.prefix(limit)), updatedAt: date)
    }

    public static var empty: FollowingSnapshot {
        FollowingSnapshot(entries: [], updatedAt: .distantPast)
    }

    public func write(in container: URL? = AppGroup.containerURL) throws {
        guard let container else { return }
        let url = AppGroup.directory(for: AppGroup.app, in: container).appending(
            path: Self.fileName)
        try AppGroupManifest.encoder.encode(self).write(to: url, options: .atomic)
    }

    public static func read(in container: URL? = AppGroup.containerURL) -> FollowingSnapshot {
        guard let container,
            let data = try? Data(
                contentsOf: AppGroup.directory(for: AppGroup.app, in: container)
                    .appending(path: fileName)),
            let snapshot = try? AppGroupManifest.decoder.decode(FollowingSnapshot.self, from: data)
        else { return .empty }
        return snapshot
    }
}
