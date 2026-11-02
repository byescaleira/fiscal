import FiscalDomain
import Foundation
import SwiftData

@Model
public class SupportEntity {
    public static let singleID = "support"

    public var id: String = SupportEntity.singleID
    public var peopleKeys: String = ""
    public var causeKeys: String = ""
    public var updatedAt: Date = Date.distantPast

    public init(support: SupportChoice, updatedAt: Date) {
        update(with: support, at: updatedAt)
    }

    func update(with support: SupportChoice, at date: Date) {
        peopleKeys = support.people.joined(separator: ",")
        causeKeys = support.causes.map(\.rawValue).joined(separator: ",")
        updatedAt = date
    }

    var support: SupportChoice {
        SupportChoice(
            people: peopleKeys.split(separator: ",").map(String.init),
            causes: causeKeys.split(separator: ",").compactMap { Theme(rawValue: String($0)) })
    }
}
