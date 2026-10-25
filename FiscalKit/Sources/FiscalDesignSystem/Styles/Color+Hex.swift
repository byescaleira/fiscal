import SwiftUI

extension Color {
    public init(hex: String?) {
        let text = (hex ?? "").trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard let value = UInt64(text, radix: 16), [6, 8].contains(text.count) else {
            self = .accentColor
            return
        }
        let rgba = text.count == 8 ? value : (value << 8) | 255
        self.init(
            .sRGB, red: Double((rgba >> 24) & 255) / 255,
            green: Double((rgba >> 16) & 255) / 255,
            blue: Double((rgba >> 8) & 255) / 255, opacity: Double(rgba & 255) / 255)
    }
}
