import CoreText
import SwiftUI

public enum EmphasisFont {
    public static let family = "Bricolage Grotesque"

    private static let registration: Void = {
        guard
            let url = Bundle.module.url(
                forResource: "BricolageGrotesque", withExtension: "ttf", subdirectory: "Fonts")
        else { return }
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }()

    @MainActor public static func register() {
        _ = registration
    }

    static func size(_ style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: 34
        case .title: 28
        case .title2: 22
        case .title3: 20
        case .headline, .body: 17
        case .callout: 16
        case .subheadline: 15
        case .footnote: 13
        case .caption: 12
        case .caption2: 11
        @unknown default: 17
        }
    }
}

extension Font {
    public static func emphasis(_ style: Font.TextStyle, weight: Font.Weight = .bold) -> Font {
        .custom(EmphasisFont.family, size: EmphasisFont.size(style), relativeTo: style)
            .weight(weight)
    }

    public static func emphasis(fixed size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .custom(EmphasisFont.family, fixedSize: size).weight(weight)
    }
}
