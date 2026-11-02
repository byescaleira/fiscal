import FiscalDomain
import Foundation

extension ProfileModel {
    public struct ThemeLine: Identifiable, Equatable {
        public let theme: Theme
        public let proposals: Int
        public let speeches: Int

        public var id: Theme { theme }

        public var actions: Int { proposals + speeches }
    }

    public var themeLines: [ThemeLine] {
        guard let profile else { return [] }
        let lines = profile.themes.map {
            ThemeLine(theme: $0.key, proposals: $0.proposals, speeches: $0.speeches)
        }
        return lines.enumerated()
            .sorted { lhs, rhs in
                (-lhs.element.actions, lhs.offset) < (-rhs.element.actions, rhs.offset)
            }
            .map(\.element)
    }

    public func themeDetail(_ line: ThemeLine) -> String {
        let proposals = PublicFormat.number(line.proposals)
        let speeches = PublicFormat.number(line.speeches)
        return String(appLocalized: "Proposals: \(proposals) · Speeches: \(speeches)")
    }

    public var themeFootnote: String {
        let order = String(
            appLocalized:
                "Themes from the proposals and speeches, the most frequent first. The numbers are the same for everyone."
        )
        let estimate = String(
            appLocalized:
                "Estimated: each one's topic comes from keywords in its official summary and can miss."
        )
        return "\(order) \(estimate)"
    }
}
