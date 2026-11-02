import FeatureCore
import FiscalDomain
import Foundation

extension RegionModel {
    nonisolated static let suggestionLimit = 8
    nonisolated static let suggestionOrder: [Office] = [
        .president, .governor, .senator, .mayor, .federalDeputy, .stateDeputy, .vicePresident,
        .viceGovernor, .viceMayor, .cityCouncilor,
    ]

    public var suggestions: [PersonCard] {
        let followedSlugs = Set(followed.map(\.card.slug))
        var included = Set<String>()
        let representatives = groups.flatMap(\.people).enumerated().sorted { lhs, rhs in
            (Self.rank(lhs.element.office), lhs.offset) < (
                Self.rank(rhs.element.office), rhs.offset
            )
        }
        .map(\.element)
        let pool = representatives.filter {
            !followedSlugs.contains($0.slug) && included.insert($0.slug).inserted
        }
        return Array(pool.prefix(Self.suggestionLimit))
    }

    nonisolated static func rank(_ office: Office) -> Int {
        suggestionOrder.firstIndex(of: office) ?? suggestionOrder.count
    }
}
