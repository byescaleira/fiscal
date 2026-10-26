import SwiftUI

extension CGFloat {
    public static let posterVictoryPortraitStories: CGFloat = 184
    public static let posterVictoryPortraitFeed: CGFloat = 100
    public static let posterVictoryPortraitMessage: CGFloat = 96
    public static let posterVictoryNameStories: CGFloat = 46
    public static let posterVictoryNameFeed: CGFloat = 30
    public static let posterVictoryNameMessage: CGFloat = 24
    public static let posterVictoryPercentStories: CGFloat = 80
    public static let posterVictoryPercentFeed: CGFloat = 52
    public static let posterVictoryPercentMessage: CGFloat = 42
    public static let posterVictoryPartyStories: CGFloat = 20
    public static let posterVictoryPartyFeed: CGFloat = 14
    public static let posterVictoryPartyMessage: CGFloat = 12
    public static let posterVictoryPartySmall: CGFloat = 9
    public static let posterVictorySealStories: CGFloat = 44
    public static let posterVictorySealFeed: CGFloat = 26
    public static let posterVictorySealMessage: CGFloat = 24
    public static let posterVictoryRingStories: CGFloat = 5
    public static let posterVictoryRing: CGFloat = 3
    public static let posterVictoryHalo: CGFloat = 1.6
    public static let posterVictoryLine: CGFloat = 3
    public static let posterVictoryTagWidth: CGFloat = 0.7
    public static let posterVictoryTagHeight: CGFloat = 0.32
}

extension Font {
    public static func posterPartyTag(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }

    public static func posterSeal(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold)
    }

    public static let posterVictoryChip = Font.system(size: 12, weight: .heavy, design: .rounded)
    public static let posterVictoryChipCompact = Font.system(
        size: 10, weight: .heavy, design: .rounded)
}
