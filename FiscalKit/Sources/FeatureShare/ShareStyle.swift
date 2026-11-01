import FiscalDesignSystem
import SwiftUI

public enum ShareStyle: String, CaseIterable, Hashable, Sendable, Identifiable {
    case poster, typographic, data

    public var id: String { rawValue }

    public var title: LocalizedStringKey {
        switch self {
        case .poster: "Poster"
        case .typographic: "Typographic"
        case .data: "Data"
        }
    }
}

extension ShareFormat {
    public var safeInsets: EdgeInsets {
        guard self == .stories else { return EdgeInsets() }
        return EdgeInsets(
            top: .shareSafeTop, leading: .shareSafeSide, bottom: .shareSafeBottom,
            trailing: .shareSafeSide)
    }

    public var safeRect: CGRect {
        let insets = safeInsets
        return CGRect(
            x: insets.leading, y: insets.top,
            width: size.width - insets.leading - insets.trailing,
            height: size.height - insets.top - insets.bottom)
    }

    public var textFormat: ShareFormat { self == .stories ? .message : self }

    public func safeExtra(beyond margin: CGFloat) -> EdgeInsets {
        let insets = safeInsets
        return EdgeInsets(
            top: Swift.max(0, insets.top - margin),
            leading: Swift.max(0, insets.leading - margin),
            bottom: Swift.max(0, insets.bottom - margin),
            trailing: Swift.max(0, insets.trailing - margin))
    }

    public var textInsets: EdgeInsets {
        let margin = textFormat.margin
        let extra = safeExtra(beyond: margin)
        return EdgeInsets(
            top: margin + extra.top, leading: margin + extra.leading,
            bottom: margin + extra.bottom, trailing: margin + extra.trailing)
    }

    public var typeFigure: CGFloat {
        switch self {
        case .stories: .shareTypeFigureStories
        case .feed: .shareTypeFigureFeed
        case .message: .shareTypeFigureMessage
        }
    }

    public var typePhrase: CGFloat {
        switch self {
        case .stories: .shareTypePhraseStories
        case .feed: .shareTypePhraseFeed
        case .message: .shareTypePhraseMessage
        }
    }

    public var dataCell: CGFloat {
        switch self {
        case .stories: .shareDataCellStories
        case .feed: .shareDataCellFeed
        case .message: .shareDataCellMessage
        }
    }

    public var safeWidth: CGFloat {
        let insets = textInsets
        return size.width - insets.leading - insets.trailing
    }

    public func phraseSize(for text: String, lines: Int) -> CGFloat {
        let characters = CGFloat(Swift.max(text.count, 1))
        let fitting = CGFloat(lines) * safeWidth / (characters * .posterStatementAdvance)
        return Swift.min(typePhrase, Swift.max(.shareTypePhraseMinimum, fitting))
    }
}
