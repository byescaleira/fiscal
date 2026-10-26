import Foundation

public struct PeerClassification: Codable, Hashable, Sendable {
    public enum Metric: String, CaseIterable, Codable, Sendable {
        case presence, quota, proposals, speeches

        public var hasDirection: Bool { self == .presence || self == .quota }

        public var title: String {
            switch self {
            case .presence: String(appLocalized: "Attendance")
            case .quota: String(appLocalized: "Office allowance per month")
            case .proposals: String(appLocalized: "Proposals")
            case .speeches: String(appLocalized: "Speeches")
            }
        }

        public var direction: String {
            switch self {
            case .presence: String(appLocalized: "Higher is better.")
            case .quota: String(appLocalized: "Lower is better, per month in office.")
            case .proposals:
                String(appLocalized: "No direction: more proposals doesn't mean better proposals.")
            case .speeches:
                String(appLocalized: "No direction: more speeches doesn't mean better work.")
            }
        }

        public func format(_ value: Double) -> String {
            switch self {
            case .presence: PublicFormat.percent(value / 100)
            case .quota:
                String(
                    appLocalized: "\(PublicFormat.compactMoney(cents: Int(value.rounded())))/month")
            case .proposals, .speeches:
                value.formatted(.number.precision(.fractionLength(0...1)).locale(.app))
            }
        }
    }

    public enum Band: String, Codable, Sendable {
        case better, average, worse, more, less

        public enum Tone: Sendable {
            case favorable, neutral, unfavorable
        }

        public var tone: Tone {
            switch self {
            case .better: .favorable
            case .worse: .unfavorable
            case .average, .more, .less: .neutral
            }
        }

        public var title: String {
            switch self {
            case .better: String(appLocalized: "Better than average")
            case .worse: String(appLocalized: "Worse than average")
            case .more: String(appLocalized: "More active than average")
            case .less: String(appLocalized: "Less active than average")
            case .average: String(appLocalized: "Around average")
            }
        }

        public var symbol: String {
            switch self {
            case .better: "arrow.up.circle"
            case .worse: "arrow.down.circle"
            case .more: "arrow.up.right"
            case .less: "arrow.down.right"
            case .average: "equal.circle"
            }
        }
    }

    public struct Entry: Codable, Hashable, Sendable {
        public let value: Double
        public let band: Band
        public let median: Double
        public let p25: Double?
        public let p75: Double?
        public let n: Int?

        public init(
            value: Double, band: Band, median: Double, p25: Double?, p75: Double?, n: Int?
        ) {
            self.value = value
            self.band = band
            self.median = median
            self.p25 = p25
            self.p75 = p75
            self.n = n
        }
    }

    public let year: Int
    public let office: String
    public let house: String
    public let uf: String?
    public let presence: Entry?
    public let quota: Entry?
    public let proposals: Entry?
    public let speeches: Entry?

    public init(
        year: Int, office: String, house: String, uf: String?, presence: Entry?, quota: Entry?,
        proposals: Entry?, speeches: Entry?
    ) {
        self.year = year
        self.office = office
        self.house = house
        self.uf = uf
        self.presence = presence
        self.quota = quota
        self.proposals = proposals
        self.speeches = speeches
    }

    public func entry(_ metric: Metric) -> Entry? {
        switch metric {
        case .presence: presence
        case .quota: quota
        case .proposals: proposals
        case .speeches: speeches
        }
    }

    public var entries: [(metric: Metric, entry: Entry)] {
        Metric.allCases.compactMap { metric in entry(metric).map { (metric, $0) } }
    }

    public func medianText(_ metric: Metric) -> String? {
        guard let entry = entry(metric) else { return nil }
        let median = metric.format(entry.median)
        switch house {
        case "senado": return String(appLocalized: "Senate median: \(median)")
        case "camara": return String(appLocalized: "Chamber median: \(median)")
        default:
            return uf == "df"
                ? String(appLocalized: "Legislative Chamber median: \(median)")
                : String(appLocalized: "Assembly median: \(median)")
        }
    }

    public func detailText(_ metric: Metric) -> String? {
        guard let entry = entry(metric), let median = medianText(metric) else { return nil }
        return String(appLocalized: "In \(String(year)): \(metric.format(entry.value)) · \(median)")
    }

    public func rangeText(_ metric: Metric) -> String? {
        guard let entry = entry(metric), let p25 = entry.p25, let p75 = entry.p75 else {
            return nil
        }
        let peers = entry.n.map { PublicFormat.number($0) } ?? PublicFormat.missing
        return String(
            appLocalized:
                "Average band: \(metric.format(p25)) to \(metric.format(p75)), among \(peers) peers in \(String(year))."
        )
    }

    public func spoken(_ metric: Metric) -> String? {
        guard let entry = entry(metric), let detail = detailText(metric) else { return nil }
        return "\(entry.band.title). \(detail)"
    }
}

public enum Relevance: String, Codable, CaseIterable, Sendable {
    case high, medium, low

    public static let highMinimum = 70
    public static let mediumMinimum = 40

    public init(weight: Int) {
        self =
            weight >= Self.highMinimum ? .high : weight >= Self.mediumMinimum ? .medium : .low
    }

    public var title: String {
        switch self {
        case .high: String(appLocalized: "High relevance")
        case .medium: String(appLocalized: "Medium relevance")
        case .low: String(appLocalized: "Low relevance")
        }
    }

    public var shortTitle: String {
        switch self {
        case .high: String(appLocalized: "High")
        case .medium: String(appLocalized: "Medium")
        case .low: String(appLocalized: "Low")
        }
    }

    public static let segments = 3

    public var filledSegments: Double {
        switch self {
        case .high: 3
        case .medium: 2
        case .low: 1
        }
    }

    public static func detail(weight: Int) -> String {
        String(appLocalized: "Weight \(weight) of 100")
    }

    public var minimumWeight: Int {
        switch self {
        case .high: Self.highMinimum
        case .medium: Self.mediumMinimum
        case .low: 0
        }
    }

    public var range: String {
        switch self {
        case .high: String(appLocalized: "Weight \(Self.highMinimum) or more")
        case .medium:
            String(appLocalized: "Weight \(Self.mediumMinimum) to \(Self.highMinimum - 1)")
        case .low: String(appLocalized: "Weight below \(Self.mediumMinimum)")
        }
    }
}
