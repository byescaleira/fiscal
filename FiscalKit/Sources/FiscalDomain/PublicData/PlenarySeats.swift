import Foundation

public struct PlenarySeats: Hashable, Sendable {
    public let yes: Int
    public let no: Int
    public let others: Int
    public let seats: Int
    public let requiredYes: Int?

    public init?(yes: Int, no: Int, others: Int, seats: Int, requiredYes: Int? = nil) {
        guard yes >= 0, no >= 0, others >= 0, seats > 0, yes + no + others <= seats else {
            return nil
        }
        self.yes = yes
        self.no = no
        self.others = others
        self.seats = seats
        self.requiredYes = requiredYes.flatMap { (1...seats).contains($0) ? $0 : nil }
    }

    public var absent: Int { seats - yes - no - others }
}
