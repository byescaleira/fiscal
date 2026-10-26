import FiscalDesignSystem
import SwiftUI

extension ShareFormat {
    public var statementBase: CGFloat {
        switch self {
        case .stories: .posterStatementStories
        case .feed: .posterStatementFeed
        case .message: .posterStatementMessage
        }
    }

    public var verdictSize: CGFloat {
        switch self {
        case .stories: .posterVerdictStories
        case .feed: .posterVerdictFeed
        case .message: .posterVerdictMessage
        }
    }

    public func statementLines(withTally: Bool) -> Int {
        switch self {
        case .stories: withTally ? 5 : 7
        case .feed: withTally ? 3 : 5
        case .message: withTally ? 2 : 4
        }
    }

    public func statementSize(for text: String, withTally: Bool) -> CGFloat {
        let characters = CGFloat(max(text.count, 1))
        let lines = CGFloat(statementLines(withTally: withTally))
        let fitting = lines * contentWidth / (characters * .posterStatementAdvance)
        return min(statementBase, max(.posterStatementMinimum, fitting))
    }
}
