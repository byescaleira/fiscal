import FiscalDesignSystem
import SwiftUI

extension CGFloat {
    static let widgetHeroShrink: CGFloat = 0.5
    static let widgetScoreShrink: CGFloat = 0.6
    static let widgetNameShrink: CGFloat = 0.7
    static let widgetLabelShrink: CGFloat = 0.8
    static let widgetTextShrink: CGFloat = 0.85
    static let widgetNoteShrink: CGFloat = 0.9
    static let electedSealScale: CGFloat = 0.32
    static let ballotSealScale: CGFloat = 0.36
    static let ballotCornerScale: CGFloat = 0.28
    static let ballotSealOffsetScale: CGFloat = 0.16
    static let islandBadge: CGFloat = 20
}

extension Double {
    static let widgetDimmed = 0.5
}

extension Font {
    static let islandScore = Font.emphasis(.caption, weight: .heavy)
    static let boardCount = Font.emphasis(.caption, weight: .semibold)

    static func electedSeal(_ side: CGFloat) -> Font {
        .system(size: side * .electedSealScale)
    }

    static func ballotSeal(_ side: CGFloat) -> Font {
        .system(size: side * .ballotSealScale)
    }
}
