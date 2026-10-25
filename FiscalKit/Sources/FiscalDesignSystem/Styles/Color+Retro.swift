import SwiftUI

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

extension Color {
    public static let retroMustard = Color(light: 0xB8841C, dark: 0xE3B04B)
    public static let retroOrange = Color(light: 0xC2602A, dark: 0xE38049)
    public static let retroRust = Color(light: 0xA63D2C, dark: 0xDC6A54)
    public static let retroOlive = Color(light: 0x5F7A2E, dark: 0x9DB35C)
    public static let retroTeal = Color(light: 0x2A7069, dark: 0x62ABA2)
    public static let retroDenim = Color(light: 0x3D5F86, dark: 0x7FA0C6)
    public static let retroPlum = Color(light: 0x74415F, dark: 0xB57FA0)
    public static let retroBrown = Color(light: 0x7E5536, dark: 0xBC8A62)
    public static let retroCream = Color(light: 0xF0E6D2, dark: 0xE6DAC2)

    init(light: UInt32, dark: UInt32) {
        #if canImport(UIKit)
            self.init(
                uiColor: UIColor {
                    $0.userInterfaceStyle == .dark ? UIColor(rgb: dark) : UIColor(rgb: light)
                })
        #elseif canImport(AppKit)
            self.init(
                nsColor: NSColor(name: nil) {
                    $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                        ? NSColor(rgb: dark) : NSColor(rgb: light)
                })
        #else
            self.init(rgb: light)
        #endif
    }
}

#if canImport(UIKit)
    extension UIColor {
        fileprivate convenience init(rgb: UInt32) {
            self.init(
                red: CGFloat((rgb >> 16) & 255) / 255, green: CGFloat((rgb >> 8) & 255) / 255,
                blue: CGFloat(rgb & 255) / 255, alpha: 1)
        }
    }
#elseif canImport(AppKit)
    extension NSColor {
        fileprivate convenience init(rgb: UInt32) {
            self.init(
                srgbRed: CGFloat((rgb >> 16) & 255) / 255, green: CGFloat((rgb >> 8) & 255) / 255,
                blue: CGFloat(rgb & 255) / 255, alpha: 1)
        }
    }
#endif
