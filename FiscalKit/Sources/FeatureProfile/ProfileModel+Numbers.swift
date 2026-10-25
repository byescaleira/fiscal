import FeatureCore
import FiscalDomain
import Foundation

extension ProfileModel {
    public struct NumberTile: Identifiable, Equatable {
        public let id: String
        public let title: String
        public let symbol: String
        public let value: String
        public let caption: String?
        public let source: String?
        public let fraction: Double?

        public var isMissing: Bool { value == PublicFormat.missing }
    }

    public var facts: [NumberTile] {
        guard let profile else { return [] }
        let numbers = profile.numbers
        return [
            attendanceTile(numbers.attendance),
            tile(
                "proposals", String(appLocalized: "Proposals"), "doc.text",
                PublicFormat.number(numbers.proposals), kind: "proposals"),
            tile(
                "laws", String(appLocalized: "Laws"), "checkmark.seal",
                PublicFormat.number(numbers.laws), kind: "proposals"),
            tile(
                "speeches", String(appLocalized: "Speeches"), "quote.bubble",
                PublicFormat.number(numbers.speeches), kind: "speeches"),
            tile(
                "votes", String(appLocalized: "Votes"), "checkmark.square",
                PublicFormat.number(numbers.votes), kind: "votes"),
            tile(
                "quota", String(appLocalized: "Office allowance"), "brazilianrealsign",
                PublicFormat.compactMoney(cents: numbers.quotaCents), kind: "expenses"),
            tile(
                "assets", String(appLocalized: "Declared assets"), "building.columns",
                PublicFormat.compactMoney(cents: numbers.assetsCents), kind: "assets"),
            tile(
                "campaign", String(appLocalized: "Campaign revenue"), "megaphone",
                PublicFormat.compactMoney(cents: numbers.campaignRevenueCents), kind: "campaigns"),
            tile(
                "election", String(appLocalized: "Votes in the last election"), "person.3",
                PublicFormat.number(numbers.lastElectionVotes), kind: "campaigns"),
        ]
    }

    public var numbersFootnote: String {
        String(
            appLocalized:
                "A dash means the source doesn't publish this number. Each number shows where it comes from."
        )
    }

    public func sourceName(for kind: String) -> String? {
        guard let profile else { return nil }
        let id = sourceID(for: kind)
        return id.flatMap { id in profile.sources.first { $0.id == id }?.name ?? id.uppercased() }
    }

    public func sourceText(for kinds: [String]) -> String? {
        let ids = Set(kinds.compactMap(sourceID(for:)))
        let matching = sources.filter { ids.contains($0.id) }
        return SourceFootnote.text(matching.isEmpty ? sources : matching, calendar: calendar)
    }

    func sourceID(for kind: String) -> String? {
        guard let profile else { return nil }
        switch kind {
        case "assets", "campaigns", "timeline":
            return profile.office.isMunicipal ? Source.municipalElectionID : Source.electionID
        default:
            if let source = profile.coverage.first(where: { $0.kind == kind })?.source {
                return source
            }
            switch profile.office {
            case .senator: return "senado"
            case .federalDeputy: return "camara"
            default: return nil
            }
        }
    }

    private func attendanceTile(_ attendance: Profile.Attendance?) -> NumberTile {
        let base = tile(
            "attendance", String(appLocalized: "Attendance"), "person.crop.circle.badge.checkmark",
            PublicFormat.percent(attendance?.fraction), kind: "attendance")
        guard let attendance, attendance.eligible > 0 else { return base }
        let present = PublicFormat.number(attendance.present)
        let eligible = PublicFormat.number(attendance.eligible)
        return NumberTile(
            id: base.id, title: base.title, symbol: base.symbol, value: base.value,
            caption: String(appLocalized: "\(present) of \(eligible) sessions"),
            source: base.source, fraction: attendance.fraction)
    }

    private func tile(
        _ id: String, _ title: String, _ symbol: String, _ value: String, kind: String
    ) -> NumberTile {
        let caption: String? =
            value == PublicFormat.missing && profile?.coverage(of: kind) == .notPublished
            ? String(appLocalized: "The house doesn't publish this") : nil
        return NumberTile(
            id: id, title: title, symbol: symbol, value: value, caption: caption,
            source: sourceName(for: kind), fraction: nil)
    }
}
