import FiscalDomain
import Foundation

public struct CompareTable: Equatable, Sendable {
    public struct Column: Equatable, Identifiable, Sendable {
        public let slug: String
        public let name: String
        public let party: String
        public let detail: String
        public let usesSecondaryColor: Bool

        public var id: String { slug }
    }

    public struct Value: Equatable, Sendable {
        public let text: String
        public let detail: String?
        public let fraction: Double?
    }

    public struct Metric: Equatable, Identifiable, Sendable {
        public let id: String
        public let title: String
        public let values: [Value]

        public func spoken(by columns: [Column]) -> String {
            zip(columns, values)
                .map { column, value in
                    [column.name, value.text, value.detail].compactMap(\.self).joined(
                        separator: ", ")
                }
                .joined(separator: "; ")
        }
    }

    public struct Group: Equatable, Identifiable, Sendable {
        public let id: String
        public let title: String
        public let metrics: [Metric]
        public let missing: [String]
        public let isLensOrdered: Bool
    }

    public let columns: [Column]
    public let groups: [Group]

    public init(profiles: [Profile], lens: Lens? = nil) {
        var seen: [String: Int] = [:]
        columns = profiles.map { profile in
            let key = SearchText.fold(profile.party)
            let repeats = seen[key, default: 0]
            seen[key] = repeats + 1
            let place = profile.uf == "br" ? "" : " · \(profile.uf.uppercased())"
            return Column(
                slug: profile.slug, name: profile.name, party: profile.party,
                detail: "\(profile.office.title)\(place)",
                usesSecondaryColor: !repeats.isMultiple(of: 2))
        }
        guard profiles.count >= 2 else {
            groups = []
            return
        }
        groups = [
            Self.office(profiles), Self.money(profiles), Self.election(profiles),
            Self.themes(profiles, lens: lens),
        ].filter { !$0.metrics.isEmpty || !$0.missing.isEmpty }
    }

    public var metricIDs: [String] { groups.flatMap { $0.metrics.map(\.id) } }

    private static func office(_ profiles: [Profile]) -> Group {
        Group(
            id: "office", title: String(appLocalized: "Term in office"),
            metrics: [
                Metric(
                    id: "attendance", title: String(appLocalized: "Attendance"),
                    values: profiles.map { profile in
                        let attendance = profile.numbers.attendance
                        return Value(
                            text: PublicFormat.percent(attendance?.fraction),
                            detail: attendance.map {
                                String(appLocalized: "\($0.present) of \($0.eligible) sessions")
                            },
                            fraction: attendance?.fraction)
                    }),
                count("votes", String(appLocalized: "Votes cast"), profiles) { $0.numbers.votes },
                count("proposals", String(appLocalized: "Proposals"), profiles) {
                    $0.numbers.proposals
                },
                count("laws", String(appLocalized: "Laws passed"), profiles) { $0.numbers.laws },
            ])
    }

    private static func money(_ profiles: [Profile]) -> Group {
        Group(
            id: "money", title: String(appLocalized: "Money"),
            metrics: [
                cents("quota", String(appLocalized: "Office allowance used"), profiles) {
                    $0.numbers.quotaCents
                },
                cents("assets", String(appLocalized: "Declared assets"), profiles) {
                    $0.numbers.assetsCents
                },
                cents("campaign", String(appLocalized: "Campaign revenue"), profiles) {
                    $0.numbers.campaignRevenueCents
                },
            ])
    }

    private static func election(_ profiles: [Profile]) -> Group {
        Group(
            id: "election", title: String(appLocalized: "Election"),
            metrics: [
                count("electionVotes", String(appLocalized: "Votes in the last election"), profiles)
                { $0.numbers.lastElectionVotes }
            ])
    }

    private static func themes(_ profiles: [Profile], lens: Lens?) -> Group {
        let present = Theme.allCases.filter { theme in
            profiles.contains { $0.themes.contains { $0.key == theme } }
        }
        let chosen = lens?.themes ?? []
        let ordered = chosen.filter(present.contains) + present.filter { !chosen.contains($0) }
        return Group(
            id: "themes", title: String(appLocalized: "Proposals by topic"),
            metrics: ordered.map { theme in
                count("theme-\(theme.rawValue)", theme.title, profiles) { profile in
                    profile.themes.first { $0.key == theme }?.proposals
                }
            },
            isLensOrdered: !chosen.isEmpty)
    }

    private static func count(
        _ id: String, _ title: String, _ profiles: [Profile], value: (Profile) -> Int?
    ) -> Metric {
        let numbers = profiles.map(value)
        return Metric(
            id: id, title: title,
            values: zip(numbers, fractions(numbers)).map {
                Value(text: PublicFormat.number($0), detail: nil, fraction: $1)
            })
    }

    private static func cents(
        _ id: String, _ title: String, _ profiles: [Profile], value: (Profile) -> Int?
    ) -> Metric {
        let numbers = profiles.map(value)
        return Metric(
            id: id, title: title,
            values: zip(numbers, fractions(numbers)).map {
                Value(text: PublicFormat.compactMoney(cents: $0), detail: nil, fraction: $1)
            })
    }

    static func fractions(_ numbers: [Int?]) -> [Double?] {
        let top = numbers.compactMap(\.self).max() ?? 0
        return numbers.map { number in
            guard let number else { return nil }
            return top > 0 ? Double(number) / Double(top) : 0
        }
    }
}

extension CompareTable.Group {
    init(
        id: String, title: String, metrics: [CompareTable.Metric], isLensOrdered: Bool = false
    ) {
        let published = metrics.filter { $0.values.contains { $0.fraction != nil } }
        self.init(
            id: id, title: title, metrics: published,
            missing: metrics.filter { !published.contains($0) }.map(\.title),
            isLensOrdered: isLensOrdered && !published.isEmpty)
    }
}
