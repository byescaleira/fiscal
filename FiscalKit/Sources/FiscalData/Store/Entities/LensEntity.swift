import FiscalDomain
import Foundation
import SwiftData

@Model
public class LensEntity {
    public var id: String = "lens"
    public var themeKeys: String = ""
    public var supportedKeys: String = ""
    public var prefersNotToSay: Bool = false
    public var artCollection: String?
    public var palette: String?
    public var icon: String?
    public var updatedAt: Date = Date.distantPast

    public init(updatedAt: Date) {
        self.updatedAt = updatedAt
    }

    var legacySupport: SupportChoice {
        SupportChoice(
            people: supportedKeys.split(separator: ",").map(String.init),
            causes: themeKeys.split(separator: ",").compactMap { Theme(rawValue: String($0)) })
    }
}
