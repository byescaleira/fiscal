import SwiftUI

extension CGFloat {
    public static let posterMargin: CGFloat = 24
    public static let posterMarginCompact: CGFloat = 18
    public static let posterHeroStories: CGFloat = 132
    public static let posterHeroFeed: CGFloat = 96
    public static let posterHeroMessage: CGFloat = 72
    public static let posterTitleStories: CGFloat = 60
    public static let posterTitleFeed: CGFloat = 40
    public static let posterTitleMessage: CGFloat = 32
    public static let posterScoreStories: CGFloat = 84
    public static let posterScoreFeed: CGFloat = 64
    public static let posterScoreMessage: CGFloat = 50
    public static let posterFactStories: CGFloat = 30
    public static let posterFactFeed: CGFloat = 24
    public static let posterFactMessage: CGFloat = 20
    public static let posterRowStories: CGFloat = 40
    public static let posterRowFeed: CGFloat = 30
    public static let posterRowMessage: CGFloat = 24
    public static let posterPlateFeed: CGFloat = 168
    public static let posterFade: CGFloat = 96
    public static let posterStripe: CGFloat = 5
    public static let posterBar: CGFloat = 6
    public static let posterCode: CGFloat = 38
    public static let posterCodeInset: CGFloat = 3
    public static let posterPlateMessage: CGFloat = 112
    public static let posterTracking: CGFloat = 1.4
    public static let posterShrink: CGFloat = 0.45
    public static let posterFigureAdvance: CGFloat = 0.52
}

extension Double {
    public static let opacityPosterScrim = 0.94
    public static let opacityPosterLabel = 0.86
    public static let opacityPosterTint = 0.32
    public static let opacityPosterSecondary = 0.74
    public static let opacityPosterQuiet = 0.6
    public static let opacityPosterTrack = 0.18
    public static let opacityPosterGlow = 0.08
}

extension Font {
    public static func posterFigure(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy).width(.condensed)
    }

    public static func posterTitle(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }

    public static let posterEyebrow = Font.system(size: 10, weight: .bold, design: .rounded)
    public static let posterHeadline = Font.system(size: 17, weight: .bold, design: .rounded)
    public static let posterHeadlineCompact = Font.system(
        size: 14, weight: .bold, design: .rounded)
    public static let posterName = Font.system(size: 17, weight: .bold, design: .rounded)
    public static let posterLabel = Font.system(size: 11, weight: .semibold, design: .rounded)
    public static let posterParty = Font.system(size: 11, weight: .heavy, design: .rounded)
    public static let posterSource = Font.system(size: 9, weight: .medium, design: .rounded)
    public static let posterCredit = Font.system(size: 7.5, weight: .medium, design: .rounded)
    public static let posterBrand = Font.system(size: 15, weight: .black, design: .rounded)
    public static let posterHost = Font.system(size: 9, weight: .semibold, design: .rounded)
}
