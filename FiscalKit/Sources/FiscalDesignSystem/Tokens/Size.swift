import SwiftUI

extension CGFloat {
    public static let badgeS: CGFloat = 28
    public static let badgeM: CGFloat = 36
    public static let badgeL: CGFloat = 44
    public static let badgeXL: CGFloat = 56
    public static let ring: CGFloat = 76
    public static let medallion: CGFloat = 112
    public static let barHeight: CGFloat = 10
    public static let rowHeight: CGFloat = 44
    #if os(tvOS)
        public static let readableColumn: CGFloat = 1100
    #else
        public static let readableColumn: CGFloat = 560
    #endif
    public static let inspectorMin: CGFloat = 320
    public static let inspectorIdeal: CGFloat = 400
    public static let inspectorMax: CGFloat = 480
}
