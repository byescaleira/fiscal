import SwiftUI

extension Font {
    public static let scoreboardHero = Font.system(size: 46, weight: .heavy).width(.condensed)
    public static let scoreboardCompact = Font.system(size: 26, weight: .bold).width(.condensed)
    public static let placeMonogram = Font.system(size: 40, weight: .black).width(.condensed)
}

extension CGFloat {
    public static let lastPlayRule: CGFloat = 3
    public static let tallyStrip: CGFloat = 6
}
