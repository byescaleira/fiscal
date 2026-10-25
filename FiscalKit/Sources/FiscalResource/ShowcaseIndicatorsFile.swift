import Foundation

public enum ShowcaseIndicatorsFile {
    public struct Source: Hashable, Sendable {
        public let id: String
        public let name: String
        public let url: String
        public let updatedAt: String
    }

    public struct Area: Hashable, Sendable {
        public let scope: String
        public let name: String
        public let start: String
        public let values: [Double?]
    }

    public struct Series: Hashable, Sendable {
        public let id: String
        public let name: String
        public let unit: String
        public let kind: String
        public let sources: [String]
        public let areas: [Area]
    }

    public static var sources: [Source] { Storage.content.sources }

    public static var series: [Series] { Storage.content.series }

    public static func decode(_ data: Data) -> (sources: [Source], series: [Series]) {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ([], [])
        }
        let sources = (root["sources"] as? [[String: Any]] ?? []).compactMap { item -> Source? in
            guard let id = item["id"] as? String, let name = item["name"] as? String,
                let url = item["url"] as? String
            else { return nil }
            return Source(
                id: id, name: name, url: url, updatedAt: item["updatedAt"] as? String ?? "")
        }
        let series = (root["indicators"] as? [[String: Any]] ?? []).compactMap(series)
        return (sources, series)
    }

    private static func series(_ item: [String: Any]) -> Series? {
        guard let id = item["id"] as? String, let name = item["name"] as? String,
            let unit = item["unit"] as? String, let kind = item["kind"] as? String,
            let rows = item["areas"] as? [[Any]]
        else { return nil }
        let areas = rows.compactMap { row -> Area? in
            guard row.count == 4, let scope = row[0] as? String, let name = row[1] as? String,
                let start = row[2] as? String, let values = row[3] as? [Any]
            else { return nil }
            return Area(
                scope: scope, name: name, start: start,
                values: values.map { ($0 as? NSNumber)?.doubleValue })
        }
        return Series(
            id: id, name: name, unit: unit, kind: kind,
            sources: item["sources"] as? [String] ?? [], areas: areas)
    }

    private enum Storage {
        static let content: (sources: [Source], series: [Series]) =
            Bundle.module.url(forResource: "showcase-indicators", withExtension: "json")
            .flatMap { try? Data(contentsOf: $0) }
            .map(decode) ?? ([], [])
    }
}
