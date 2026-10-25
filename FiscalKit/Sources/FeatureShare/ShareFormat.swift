import FiscalDesignSystem
import SwiftUI

public enum ShareFormat: String, CaseIterable, Identifiable, Sendable {
    case stories, feed, message

    public var id: String { rawValue }

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

    public var artShare: CGFloat {
        switch self {
        case .stories: 0.42
        case .feed: 0.26
        case .message: 0.16
        }
    }

    public var isCompact: Bool { self == .message }

    public var showsCode: Bool { self != .message }

    public func pixels(scale: CGFloat) -> CGSize {
        CGSize(width: size.width * scale, height: size.height * scale)
    }
}
