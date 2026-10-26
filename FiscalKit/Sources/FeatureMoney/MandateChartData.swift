import FiscalDomain
import Foundation

public struct MandateSegment: Identifiable, Equatable, Sendable {
    public let role: MandateCost.Role
    public let kind: MandateCost.Kind
    public let cents: Int
    public let isLast: Bool

    public var id: String { "\(role.rawValue)-\(kind.rawValue)" }
    public var roleTitle: String { role.title }
    public var kindTitle: String { MandateText.kindTitle(kind) }
    public var slot: Int { MandateCost.Kind.allCases.firstIndex(of: kind) ?? 0 }
    public var reais: Double { Double(cents) / 100 }
    public var value: String { PublicFormat.money(cents: cents) }
}

public struct MandateRoleTotal: Identifiable, Equatable, Sendable {
    public let role: MandateCost.Role
    public let monthlyCents: Int
    public let unpublished: [MandateCost.Kind]

    public var id: String { role.rawValue }
    public var title: String { role.title }
    public var yearlyCents: Int { monthlyCents * 12 }
    public var monthly: String { PublicFormat.money(cents: monthlyCents) }
    public var compactMonthly: String { PublicFormat.compactMoney(cents: monthlyCents) }
    public var yearly: String { PublicFormat.compactMoney(cents: yearlyCents) }
    public var fullYearly: String { PublicFormat.money(cents: yearlyCents) }
}

public struct MandateActItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let act: String
    public let url: URL?
}

public struct QuotaStateBar: Identifiable, Equatable, Sendable {
    public let uf: String
    public let cents: Int
    public let isSelected: Bool

    public var id: String { uf }
    public var code: String { uf.uppercased(with: .app) }
    public var title: String { RaceText.scope(uf) }
    public var reais: Double { Double(cents) / 100 }
    public var value: String { PublicFormat.money(cents: cents) }
}

public enum MandateText {
    public static let fallbackUF = "df"

    public static func kindTitle(_ kind: MandateCost.Kind) -> String {
        switch kind {
        case .salary: String(appLocalized: "Official salary")
        case .quota: String(appLocalized: "Office allowance")
        case .staff: String(appLocalized: "Staff budget")
        case .housing: String(appLocalized: "Housing allowance")
        }
    }

    public static func day(_ day: CalendarDay) -> String {
        String(format: "%02d/%02d/%04d", day.day, day.month, day.year)
    }

    public static func multiple(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)).locale(.app))
    }

    public static func act(_ act: MandateCost.Act) -> String {
        guard let since = act.since else { return act.name }
        return String(appLocalized: "\(act.name), in force since \(day(since))")
    }
}
