import SwiftUI

extension Font {
    public static let scoreboardHero = Font.emphasis(fixed: 46, weight: .heavy)
    public static let scoreboardCompact = Font.emphasis(fixed: 26, weight: .bold)
    public static let placeMonogram = Font.emphasis(fixed: 40, weight: .black)
    public static let candidatePercentLarge = Font.emphasis(fixed: 40, weight: .heavy)
    public static let candidatePercentCompact = Font.emphasis(fixed: 26, weight: .heavy)

    public static func ballotNumber(_ side: CGFloat) -> Font {
        .emphasis(fixed: side * .ballotNumberScale, weight: .heavy)
    }
}

extension CGFloat {
    public static let lastPlayRule: CGFloat = 3
    public static let tallyStrip: CGFloat = 6
    public static let ballotNumberScale: CGFloat = 0.42
}
