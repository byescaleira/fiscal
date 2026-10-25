import FiscalDomain
import Foundation
import SwiftData

@Model
public class LensEntity {
    public static let singleID = "lens"

    public var id: String = LensEntity.singleID
    public var themeKeys: String = ""
    public var stance: String?
    public var artCollection: String?
    public var palette: String?
    public var updatedAt: Date = Date.distantPast

    public init(lens: Lens, updatedAt: Date) {
        update(with: lens, at: updatedAt)
    }

    func update(with lens: Lens, at date: Date) {
        themeKeys = lens.themes.map(\.rawValue).joined(separator: ",")
        stance = lens.stance?.rawValue
        artCollection = lens.artCollection
        palette = lens.palette
        updatedAt = date
    }

    var lens: Lens {
        Lens(
            themes: themeKeys.split(separator: ",").compactMap { Theme(rawValue: String($0)) },
            stance: stance.flatMap(PoliticalStance.init(rawValue:)),
            artCollection: artCollection, palette: palette)
    }
}
