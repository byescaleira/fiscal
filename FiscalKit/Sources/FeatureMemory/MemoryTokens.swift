import FiscalDesignSystem
import SwiftUI

extension CGFloat {
    static let winnerCardShare: CGFloat = 0.82
    static let winnerCardColumnShare: CGFloat = 0.7
    static let studyCardShare: CGFloat = 0.86
    static let studyCardColumnShare: CGFloat = 0.8
    static let studyCardMinHeight: CGFloat = 280
    static let heroPortraitEntryScale: CGFloat = 0.6

    static func railCard(in width: CGFloat, share: CGFloat, columnShare: CGFloat) -> CGFloat {
        Swift.min(width * share, .readableColumn * columnShare)
    }
}
