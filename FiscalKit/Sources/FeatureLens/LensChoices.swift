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

public enum LensText {
    public static func firstThemes(_ themes: [Theme]) -> String? {
        guard !themes.isEmpty else { return nil }
        let names = themes.prefix(2).map(\.title).joined(separator: ", ")
        if themes.count > 2 {
            return String(appLocalized: "First: \(names)…")
        }
        return String(appLocalized: "First: \(names)")
    }

    public static let sampleParties = ["MDB", "PL", "PT"]

    public static func sampleHeadline(_ theme: Theme) -> String {
        String(appLocalized: "Example: a floor vote on \(theme.title)")
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
