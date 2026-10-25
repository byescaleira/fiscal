import Foundation

public struct LensPreset: Hashable, Sendable {
    public let themes: [Theme]
    public let palette: String
    public let artCollection: String

    public init(themes: [Theme], palette: String, artCollection: String) {
        self.themes = themes
        self.palette = palette
        self.artCollection = artCollection
    }

    public static func suggested(for stance: PoliticalStance) -> LensPreset {
        switch stance.effective {
        case .right:
            LensPreset(
                themes: [.taxes, .security, .politics, .economy], palette: "forest",
                artCollection: "brasil-agora")
        case .centerRight:
            LensPreset(
                themes: [.economy, .taxes, .security, .health], palette: "indigo",
                artCollection: "brasil-agora")
        case .center:
            LensPreset(
                themes: [.economy, .health, .education, .politics], palette: "savanna",
                artCollection: "brasil-agora")
        case .centerLeft:
            LensPreset(
                themes: [.health, .education, .social, .environment], palette: "ipe",
                artCollection: "brasil-agora")
        case .left:
            LensPreset(
                themes: [.social, .environment, .rights, .education], palette: "annatto",
                artCollection: "brasil-agora")
        case .impartial, .preferNotToSay:
            LensPreset(
                themes: [.taxes, .security, .politics, .social, .environment],
                palette: "graphite", artCollection: "brasil-agora")
        }
    }

    public func lens(stance: PoliticalStance) -> Lens {
        Lens(themes: themes, stance: stance, artCollection: artCollection, palette: palette)
    }
}

extension PoliticalStance {
    public var counterpart: PoliticalStance {
        switch effective {
        case .right: .left
        case .left: .right
        case .centerRight: .centerLeft
        case .centerLeft: .centerRight
        case .center, .impartial, .preferNotToSay: .impartial
        }
    }
}

extension Theme {
    public static var setupChoices: [Theme] {
        [
            .health, .education, .security, .economy, .taxes, .environment,
            .social, .rights, .politics, .city, .countryside, .women,
        ]
    }

    public static var moreChoices: [Theme] {
        allCases.filter { !setupChoices.contains($0) }
    }
}
