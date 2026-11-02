import FeatureCore
import FiscalDomain
import Foundation

extension ProfileModel {
    public var chapters: [ProfileChapter] {
        guard let profile else { return [] }
        return ProfileChapter.order(for: profile.office).filter(hasContent)
    }

    public func facts(in chapter: ProfileChapter) -> [NumberTile] {
        facts.filter { Self.chapter(ofFact: $0.id) == chapter }
    }

    public func moveCurrentChapter(tops: [ProfileChapter: CGFloat], line: CGFloat) {
        let next = Self.chapter(in: chapters, tops: tops, line: line)
        if next != currentChapter { currentChapter = next }
    }

    static func chapter(
        in order: [ProfileChapter], tops: [ProfileChapter: CGFloat], line: CGFloat
    ) -> ProfileChapter? {
        order.last { chapter in tops[chapter].map { $0 <= line } ?? false }
    }

    public var gaps: [String] {
        guard let profile else { return [] }
        let unpublished = profile.coverage.filter { $0.status == .notPublished }
        let unread = profile.coverage.filter { $0.status == .notLoaded }
        var lines: [String] = []
        if !unpublished.isEmpty {
            lines.append(
                profile.office.isLegislative
                    ? String(
                        appLocalized:
                            "This house doesn't publish as open data: \(Self.list(unpublished)).")
                    : String(
                        appLocalized:
                            "The open sources Fiscal reads don't have \(Self.list(unpublished)) for this office."
                    ))
        }
        if !unread.isEmpty {
            lines.append(String(appLocalized: "Not loaded yet: \(Self.list(unread))."))
        }
        return lines
    }

    private func hasContent(_ chapter: ProfileChapter) -> Bool {
        guard let profile else { return false }
        switch chapter {
        case .votes:
            return !facts(in: .votes).isEmpty || !recentVotes.isEmpty
        case .proposals:
            return !facts(in: .proposals).isEmpty || !actionItems.isEmpty
                || !recentProposals.isEmpty || !recentSpeeches.isEmpty || !committees.isEmpty
        case .money:
            return !facts(in: .money).isEmpty || hasExpenses || profile.salary != nil
        case .origin:
            return !facts(in: .origin).isEmpty || !assetDeclarations.isEmpty
                || !campaigns.isEmpty || !timeline.isEmpty
        case .term:
            return hasContext
        case .checks:
            return !checkItems.isEmpty
        case .about:
            return !aboutLines.isEmpty || !gaps.isEmpty
        }
    }

    private static func chapter(ofFact id: String) -> ProfileChapter? {
        switch id {
        case "attendance", "votes": .votes
        case "proposals", "laws", "speeches": .proposals
        case "quota": .money
        case "assets", "campaign", "election": .origin
        default: nil
        }
    }

    private static func list(_ coverage: [Profile.Coverage]) -> String {
        coverage.map { coverageTitle($0.kind).lowercased(with: .app) }
            .formatted(.list(type: .and).locale(.app))
    }
}
