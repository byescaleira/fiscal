import FiscalDomain
import Foundation
import SwiftData

@Model
public class LensEntity {
    public static let singleID = "lens"

    public var id: String = LensEntity.singleID
    public var themeKeys: String = ""
    public var supportedKeys: String = ""
    public var prefersNotToSay: Bool = false
    public var artCollection: String?
    public var palette: String?
    public var icon: String?
    public var updatedAt: Date = Date.distantPast

    public init(lens: Lens, updatedAt: Date) {
        update(with: lens, at: updatedAt)
    }

    func update(with lens: Lens, at date: Date) {
        themeKeys = lens.themes.map(\.rawValue).joined(separator: ",")
        supportedKeys = lens.supported.joined(separator: ",")
        prefersNotToSay = lens.prefersNotToSay
        artCollection = lens.artCollection
        palette = lens.palette
        icon = lens.icon
        updatedAt = date
    }

    var lens: Lens {
        Lens(
            themes: themeKeys.split(separator: ",").compactMap { Theme(rawValue: String($0)) },
            supported: supportedKeys.split(separator: ",").map(String.init),
            prefersNotToSay: prefersNotToSay, artCollection: artCollection, palette: palette,
            icon: icon)
    }
}
