import FiscalDesignSystem
import SwiftUI

public enum ShareFormat: String, CaseIterable, Identifiable, Sendable {
    case stories, feed, message

    public var id: String { rawValue }

    public var raceRowLimit: Int {
        switch self {
        case .stories: 8
        case .feed: 5
        case .message: 3
        }
    }

    public var title: LocalizedStringKey {
        switch self {
        case .stories: "Stories"
        case .feed: "Feed"
        case .message: "Message"
        }
    }

    public var ratio: String {
        switch self {
        case .stories: "9:16"
        case .feed: "4:5"
        case .message: "1:1"
        }
    }

    public var size: CGSize {
        switch self {
        case .stories: CGSize(width: .shareCanvasWidth, height: .shareStoriesHeight)
        case .feed: CGSize(width: .shareCanvasWidth, height: .shareFeedHeight)
        case .message: CGSize(width: .shareCanvasWidth, height: .shareMessageHeight)
        }
    }

    public var heroSize: CGFloat {
        switch self {
        case .stories: .posterHeroStories
        case .feed: .posterHeroFeed
        case .message: .posterHeroMessage
        }
    }

    public var titleSize: CGFloat {
        switch self {
        case .stories: .posterTitleStories
        case .feed: .posterTitleFeed
        case .message: .posterTitleMessage
        }
    }

    public var scoreSize: CGFloat {
        switch self {
        case .stories: .posterScoreStories
        case .feed: .posterScoreFeed
        case .message: .posterScoreMessage
        }
    }

    public var rowSize: CGFloat {
        switch self {
        case .stories: .posterRowStories
        case .feed: .posterRowFeed
        case .message: .posterRowMessage
        }
    }

    public var factSize: CGFloat {
        switch self {
        case .stories: .posterFactStories
        case .feed: .posterFactFeed
        case .message: .posterFactMessage
        }
    }

    public var contentWidth: CGFloat {
        size.width - margin * 2
    }

    public func figureSize(_ base: CGFloat, for value: String, in width: CGFloat? = nil) -> CGFloat
    {
        let characters = CGFloat(max(value.count, 1))
        return min(base, (width ?? contentWidth) / (characters * .posterFigureAdvance))
    }

    public var column: CGFloat {
        (size.width - margin * 2 - .spaceL) / 2
    }

    public var margin: CGFloat {
        self == .stories ? .posterMargin : .posterMarginCompact
    }

    public var plateSpansWidth: Bool { self == .stories }

    public var plateWidth: CGFloat {
        switch self {
        case .stories: .shareCanvasWidth
        case .feed: .posterPlateFeed
        case .message: .posterPlateMessage
        }
    }

    public var headlineLines: Int {
        switch self {
        case .stories: 4
        case .feed: 3
        case .message: 2
        }
    }

    public var showsFacts: Bool { self == .stories }

    public var showsNote: Bool { self == .stories }

    public var compareRows: Int { self == .message ? 2 : SharePoster.compareLimit }

    public var showsCode: Bool { self != .message }

    public func pixels(scale: CGFloat) -> CGSize {
        CGSize(width: size.width * scale, height: size.height * scale)
    }
}
