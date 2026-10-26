import SwiftUI

extension CGFloat {
    public static let shareCanvasWidth: CGFloat = 360
    public static let shareStoriesHeight: CGFloat = 640
    public static let shareFeedHeight: CGFloat = 450
    public static let shareMessageHeight: CGFloat = 360
    public static let shareRadius: CGFloat = 14
    public static let sharePortrait: CGFloat = 52
    public static let sharePortraitSmall: CGFloat = 30
    public static let shareCode: CGFloat = 54
    public static let shareStripe: CGFloat = 4
    public static let shareBar: CGFloat = 8
    public static let shareThumbnail: CGFloat = 56
    public static let sharePreviewMax: CGFloat = 520
    public static let shareTextShrink: CGFloat = 0.6
    public static let shareArtFade: CGFloat = 0.7
    public static let shareBlur: CGFloat = 24
    public static let galleryArtwork: CGFloat = 240
    public static let galleryColumn: CGFloat = 300
    public static let gallerySwatch: CGFloat = 14
}

extension Double {
    public static let opacityShareBlock = 0.94
    public static let opacityShareBand = 0.45
    public static let opacityShareShade = 0.6
}

extension Font {
    public static let shareHero = Font.system(size: 46, weight: .heavy).width(.condensed)
    public static let shareNumber = Font.system(size: 28, weight: .heavy).width(.condensed)
    public static let shareTitle = Font.system(size: 19, weight: .bold, design: .rounded)
    public static let shareName = Font.system(size: 16, weight: .bold, design: .rounded)
    public static let shareBody = Font.system(size: 11, weight: .medium, design: .rounded)
    public static let shareLabel = Font.system(size: 9, weight: .bold, design: .rounded)
    public static let shareCredit = Font.system(size: 8, weight: .semibold, design: .rounded)
    public static let shareStamp = Font.system(size: 7.5, weight: .medium, design: .monospaced)
    public static let shareBrand = Font.system(size: 15, weight: .black, design: .rounded)
}
