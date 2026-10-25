import SwiftUI

public enum ChartPalette {
    public static let categorical: [Color] = [
        Color(light: 0x008B9A, dark: 0x0191A0),
        Color(light: 0xB06436, dark: 0xB86838),
        Color(light: 0x7C58A3, dark: 0x9976C1),
        Color(light: 0xAA8B2E, dark: 0xA0832A),
        Color(light: 0x9B4A6C, dark: 0xBF6A8D),
        Color(light: 0x4665AE, dark: 0x607EC2),
    ]

    public static let other = Color.secondary

    public static func color(at slot: Int) -> Color {
        categorical.indices.contains(slot) ? categorical[slot] : other
    }
}

extension CGFloat {
    public static let chartCompactHeight: CGFloat = 140
    public static let chartRowHeight: CGFloat = 46
    public static let chartRuleWidth: CGFloat = 1
}
