import FiscalDomain

public struct MonthChoice: Identifiable, Hashable, Sendable {
    public enum Time: Sendable {
        case past, current, future
    }

    public let month: YearMonth
    public let title: String
    public let fullTitle: String
    public let isSelected: Bool
    public let time: Time
    public let isAvailable: Bool
    public let detail: String

    public var id: Int { month.rawValue }
}
