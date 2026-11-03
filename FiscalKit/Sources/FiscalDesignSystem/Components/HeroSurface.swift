import SwiftUI

public enum HeroTone: Hashable, Sendable {
    case vote
    case colors([Color])

    public var tints: [Color] {
        switch self {
        case .vote: [.voteYes, .voteNo]
        case .colors(let colors): colors
        }
    }
}

extension Color {
    public static let heroInk = Color(light: 0x000000, dark: 0xFFFFFF)
}

extension ShapeStyle where Self == Color {
    public static var heroInk: Color { Color.heroInk }
}

public struct HeroInk: Sendable {
    private let isDark: Bool

    public init(_ colorScheme: ColorScheme) {
        isDark = colorScheme == .dark
    }

    public var primary: Color { isDark ? .white : .primary }

    public var secondary: Color {
        isDark ? .white.opacity(.opacityStrong) : .primary.opacity(.opacityStrong)
    }

    public var dimmed: Color {
        isDark ? .white.opacity(.opacitySoft) : .primary.opacity(.opacityStrong)
    }

    public var track: Color {
        isDark ? .white.opacity(.opacityTint) : .secondary.opacity(.opacityTint)
    }

    public func signal(_ color: Color) -> Color { isDark ? .white : color }
}

public struct HeroSurface<Dark: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    private let tone: HeroTone
    private let cornerRadius: CGFloat
    private let dark: Dark

    public init(
        _ tone: HeroTone, cornerRadius: CGFloat = .radiusGroup, @ViewBuilder dark: () -> Dark
    ) {
        self.tone = tone
        self.cornerRadius = cornerRadius
        self.dark = dark()
    }

    public var body: some View {
        if colorScheme == .dark {
            dark
        } else if contrast == .increased {
            Color.plainRow
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(.primary, lineWidth: .spaceHairline)
                }
        } else {
            let tints = tone.tints
            LinearGradient(
                colors: [
                    (tints.first ?? .clear).opacity(.opacitySoft), Color.plainRow,
                    (tints.last ?? .clear).opacity(.opacitySoft),
                ], startPoint: .leading, endPoint: .trailing
            )
            .background(Color.plainRow)
        }
    }
}
