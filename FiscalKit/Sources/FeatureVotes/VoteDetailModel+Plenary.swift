import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import Foundation

public struct PlenaryLegendItem: Hashable, Identifiable, Sendable {
    public let group: HemicycleLayout.Group
    public let count: Int
    public let title: String

    public var id: HemicycleLayout.Group { group }
}

extension VoteDetailModel {
    public static let chamberSeats = 513
    public static let senateSeats = 81

    public var seats: Int? {
        guard let vote else { return nil }
        switch vote.house {
        case .camara: return Self.chamberSeats
        case .senado: return Self.senateSeats
        }
    }

    public var plenary: PlenarySeats? {
        guard let vote, vote.nominal, hasScore, let seats, (vote.tally.total ?? 0) > 0 else {
            return nil
        }
        return PlenarySeats(
            yes: vote.yes ?? 0, no: vote.no ?? 0, others: vote.others ?? 0, seats: seats,
            requiredYes: requiredYes)
    }

    public var plenaryLayout: HemicycleLayout? {
        plenary.map { HemicycleLayout(yes: $0.yes, no: $0.no, others: $0.others, seats: $0.seats) }
    }

    public var plenaryLegend: [PlenaryLegendItem] {
        guard let plenary else { return [] }
        return [
            PlenaryLegendItem(
                group: .yes, count: plenary.yes,
                title: String(appLocalized: "\(plenary.yes) yes")),
            PlenaryLegendItem(
                group: .no, count: plenary.no, title: String(appLocalized: "\(plenary.no) no")),
            PlenaryLegendItem(
                group: .other, count: plenary.others,
                title: String(appLocalized: "\(plenary.others) others")),
            PlenaryLegendItem(
                group: .absent, count: plenary.absent,
                title: String(appLocalized: "\(plenary.absent) did not vote")),
        ]
    }

    public var plenaryAccessibility: String? {
        guard let plenary else { return nil }
        let counts = plenaryLegend.map(\.title).formatted(.list(type: .and).locale(.app))
        let floor = String(appLocalized: "Floor: \(counts), out of \(plenary.seats) seats")
        guard let required = plenary.requiredYes else { return floor }
        return [floor, String(appLocalized: "\(required) yes votes to pass")]
            .joined(separator: ". ")
    }
}
