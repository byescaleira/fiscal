import SwiftUI

extension Font {
    public static let scoreboardNumber = Font.emphasis(fixed: 34, weight: .bold)
    public static let scoreboardTitle = Font.emphasis(.largeTitle, weight: .bold)
}

extension CGFloat {
    public static let portraitAnimated: CGFloat = 72
    public static let railTitleMargin: CGFloat = .spaceL * 2
}

extension Color {
    public static let scoreboard = Color(light: 0x0F1717, dark: 0x0F1717)
    public static let scoreboardAccent = Color(light: 0x62ABA2, dark: 0x62ABA2)
}
