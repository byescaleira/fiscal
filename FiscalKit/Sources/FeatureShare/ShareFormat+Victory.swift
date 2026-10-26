import FiscalDesignSystem
import SwiftUI

extension ShareFormat {
    public var victoryPortrait: CGFloat {
        switch self {
        case .stories: .posterVictoryPortraitStories
        case .feed: .posterVictoryPortraitFeed
        case .message: .posterVictoryPortraitMessage
        }
    }

    public var victoryName: CGFloat {
        switch self {
        case .stories: .posterVictoryNameStories
        case .feed: .posterVictoryNameFeed
        case .message: .posterVictoryNameMessage
        }
    }

    public var victoryPercent: CGFloat {
        switch self {
        case .stories: .posterVictoryPercentStories
        case .feed: .posterVictoryPercentFeed
        case .message: .posterVictoryPercentMessage
        }
    }

    public var victoryParty: CGFloat {
        switch self {
        case .stories: .posterVictoryPartyStories
        case .feed: .posterVictoryPartyFeed
        case .message: .posterVictoryPartyMessage
        }
    }

    public var victorySeal: CGFloat {
        switch self {
        case .stories: .posterVictorySealStories
        case .feed: .posterVictorySealFeed
        case .message: .posterVictorySealMessage
        }
    }

    public var victoryRing: CGFloat {
        self == .stories ? .posterVictoryRingStories : .posterVictoryRing
    }

    public var victoryIsSideBySide: Bool { self == .message }

    public var victorySpacing: CGFloat { self == .stories ? .spaceM : .spaceS }

    public var victoryChip: Font {
        self == .stories ? .posterVictoryChip : .posterVictoryChipCompact
    }

    public var victoryStatement: Font {
        self == .stories ? .posterHeadline : .posterHeadlineCompact
    }

    public var victoryRunnerName: Font {
        self == .stories ? .posterName : .posterLabel
    }

    public var victoryShowsRunnerPortrait: Bool { self != .message }
}
