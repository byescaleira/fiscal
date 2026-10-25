import SwiftUI

public enum IconSize: CGFloat, Sendable {
    case xs = 10
    case s = 18
    case m = 20
    case l = 30
    case xl = 50
    case hero = 130
}

extension Font {
    public static func icon(_ size: IconSize, weight: Font.Weight = .regular) -> Font {
        .system(size: size.rawValue, weight: weight)
    }
}
