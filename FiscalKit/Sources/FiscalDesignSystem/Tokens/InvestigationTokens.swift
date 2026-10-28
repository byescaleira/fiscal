import SwiftUI

extension CGFloat {
    public static let posterCasePortraitStories: CGFloat = 58
    public static let posterCasePortraitFeed: CGFloat = 42
    public static let posterCasePortraitMessage: CGFloat = 32
    public static let posterCaseQuestionStories: CGFloat = 34
    public static let posterCaseQuestionFeed: CGFloat = 26
    public static let posterCaseQuestionMessage: CGFloat = 22
    public static let posterCaseQuestionMinimum: CGFloat = 16
    public static let posterCaseNumberStories: CGFloat = 44
    public static let posterCaseNumberFeed: CGFloat = 34
    public static let posterCaseNumberMessage: CGFloat = 28
    public static let posterCaseGrid: CGFloat = 14
    public static let posterCaseDot: CGFloat = 1.2
    public static let posterCaseThread: CGFloat = 1.5
    public static let posterCaseAdvance: CGFloat = 0.5
    public static let caseQuestionField: CGFloat = 76
    public static let caseDoor: CGFloat = 92
    public static let caseSuggestion: CGFloat = 244
    public static let casePiece: CGFloat = 132
    public static let caseThread: CGFloat = 2
    public static let caseStrip: CGFloat = 26
    public static let caseStripDot: CGFloat = 12
    public static let caseMirror: CGFloat = 8
}

extension Double {
    public static let opacityCaseGrid = 0.14
    public static let opacityCaseBand = 0.28
}

extension Font {
    public static let caseQuestion = Font.emphasis(.title2, weight: .bold)
    public static let caseNumber = Font.emphasis(.largeTitle, weight: .heavy)
    public static let caseKicker = Font.caption2.weight(.heavy)
}
