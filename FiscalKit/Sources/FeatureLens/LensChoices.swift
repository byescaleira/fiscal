import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import Foundation

extension LensPaletteSwatch {
    public var appIcon: AppIcon {
        switch self {
        case .forest: .themeForest
        case .annatto: .themeAnnatto
        case .indigo: .themeIndigo
        case .ipe: .themeIpe
        case .savanna: .themeSavanna
        case .sea: .themeSea
        case .graphite: .themeGraphite
        case .sand: .themeSand
        }
    }

    public static var grid: [LensPaletteSwatch] {
        leading.flatMap { [$0, $0.mirror] }
    }
}

extension PoliticalStance {
    public static var spectrum: [PoliticalStance] {
        [.left, .centerLeft, .center, .centerRight, .right]
    }

    public static var neutral: [PoliticalStance] { [.impartial, .preferNotToSay] }

    public var isOnSpectrum: Bool { Self.spectrum.contains(self) }

    public var choiceSymbol: String {
        switch self {
        case .impartial: "scale.3d"
        case .preferNotToSay: "hand.raised"
        default: "circle.fill"
        }
    }

    public var choiceDetail: String {
        switch self {
        case .impartial:
            String(appLocalized: "Both sides, balanced and side by side.")
        case .preferNotToSay:
            String(appLocalized: "Works like Impartial. Nothing else is asked.")
        default: title
        }
    }
}

public enum LensText {
    public static func firstThemes(_ themes: [Theme]) -> String? {
        guard !themes.isEmpty else { return nil }
        let names = themes.prefix(2).map(\.title).joined(separator: ", ")
        if themes.count > 2 {
            return String(appLocalized: "First: \(names)…")
        }
        return String(appLocalized: "First: \(names)")
    }

    public static func effect(for stance: PoliticalStance) -> String {
        if stance.isImpartial {
            return String(
                appLocalized:
                    "Highlights take turns between both sides, comparisons sit side by side and Another lens stays open."
            )
        }
        return String(
            appLocalized:
                "Today, Votes and Money open with these topics. Everything else stays one tap away."
        )
    }

    public static let sampleParties = ["MDB", "PL", "PT"]

    public static func sampleHeadline(_ theme: Theme) -> String {
        String(appLocalized: "Example: a floor vote on \(theme.title)")
    }

    public static func choiceTitle(for stance: PoliticalStance) -> String {
        String(appLocalized: "With the \(stance.effective.title) lens")
    }
}

public enum LensIcons {
    public static func choices(suggested: AppIcon?) -> [AppIcon] {
        let themed = AppIcon.Collection.themes.icons
        guard let suggested, themed.contains(suggested) else { return [.standard] + themed }
        return [.standard, suggested] + themed.filter { $0 != suggested }
    }
}

public struct LensThemeTally: Equatable, Sendable {
    public struct Slice: Equatable, Identifiable, Sendable {
        public let theme: Theme
        public let slot: Int
        public let votes: [VoteSummary]

        public var id: String { theme.rawValue }

        public var count: Int { votes.count }

        public var approved: Int { votes.count { $0.approved == true } }

        public var rejected: Int { votes.count { $0.approved == false } }
    }

    public let total: Int
    public let slices: [Slice]

    public init(votes: [VoteSummary], themes: [Theme]) {
        total = votes.count
        slices = themes.enumerated()
            .map { slot, theme in
                Slice(theme: theme, slot: slot, votes: votes.filter { $0.themes.contains(theme) })
            }
            .sorted { ($0.count, -$0.slot) > ($1.count, -$1.slot) }
    }

    public var touchesThemes: Bool { slices.contains { $0.count > 0 } }

    public var maxCount: Int { slices.map(\.count).max() ?? 0 }

    public func slice(of theme: Theme) -> Slice? { slices.first { $0.theme == theme } }

    public var headline: String {
        guard let first = slices.first, first.count > 0 else {
            return String(appLocalized: "None of the latest votes touched these topics")
        }
        let second = slices.dropFirst().first?.count ?? 0
        if first.count > second {
            return String(appLocalized: "\(first.theme.title) had the most votes")
        }
        return String(appLocalized: "More than one topic tied in the latest votes")
    }
}
