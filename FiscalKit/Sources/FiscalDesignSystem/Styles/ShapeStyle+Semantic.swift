import SwiftUI

extension ShapeStyle where Self == Color {
    public static var positive: Color { .retroOlive }
    public static var negative: Color { .retroRust }
    public static var warning: Color { .retroMustard }
    public static var info: Color { .retroDenim }
    public static var companion: Color { .retroDenim }
    public static var disabled: Color { .gray }
    public static var subtleFill: Color { Color.secondary.opacity(.opacityFill) }
    public static var rowFill: Color { Color.secondary.opacity(0.08) }
}
