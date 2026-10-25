import SwiftUI

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

extension ShapeStyle where Self == Color {
    public static var groupedBackground: Color {
        #if os(macOS)
            Color(nsColor: .windowBackgroundColor)
        #elseif os(visionOS) || os(tvOS)
            .clear
        #else
            Color(uiColor: .systemGroupedBackground)
        #endif
    }

    public static var groupedRow: Color {
        #if os(macOS)
            Color(nsColor: .controlBackgroundColor)
        #elseif os(visionOS) || os(tvOS)
            Color.secondary.opacity(.opacityFill)
        #else
            Color(uiColor: .secondarySystemGroupedBackground)
        #endif
    }

    public static var sheetBackground: Color {
        #if os(macOS)
            Color(nsColor: .windowBackgroundColor)
        #elseif os(visionOS) || os(tvOS)
            .clear
        #else
            Color(uiColor: .systemBackground)
        #endif
    }

    public static var sheetCard: Color {
        #if os(macOS)
            Color(nsColor: .controlBackgroundColor)
        #elseif os(visionOS) || os(tvOS)
            Color.secondary.opacity(.opacityFill)
        #else
            Color(uiColor: .secondarySystemBackground)
        #endif
    }
}
