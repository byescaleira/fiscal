import FiscalDomain
import Foundation

extension SearchModel {
    public var themeActivity: ThemeActivity? {
        guard let recentVotes else { return nil }
        return ThemeActivity(votes: recentVotes, themes: themes)
    }

    public var isLoadingThemes: Bool {
        recentVotes == nil && (phase == .idle || phase == .loading)
    }

    public func headline(for activity: ThemeActivity) -> String {
        if let leader = activity.leader {
            return String(appLocalized: "\(leader.theme.title) had the most votes")
        }
        if activity.touchesThemes {
            return String(appLocalized: "More than one topic tied in the latest votes")
        }
        return String(appLocalized: "None of the latest votes touched these topics")
    }

    public func countText(_ count: Int) -> String {
        String(appLocalized: "Votes: \(count)")
    }

    public func approvedText(for slice: ThemeActivity.Slice) -> String? {
        guard slice.approved > 0, slice.approved < slice.count else { return nil }
        return String(appLocalized: "Approved: \(slice.approved)")
    }

    public func accessibilityValue(for slice: ThemeActivity.Slice) -> String {
        String(
            appLocalized:
                "Votes: \(slice.count), approved: \(slice.approved), rejected: \(slice.rejected)")
    }

    public func averageText(for activity: ThemeActivity) -> String? {
        guard let average = activity.average else { return nil }
        let value = average.formatted(.number.precision(.fractionLength(0...1)).locale(.app))
        switch activity.grain {
        case .day: return String(appLocalized: "Dashed line: average of \(value) per day")
        case .week: return String(appLocalized: "Dashed line: average of \(value) per week")
        }
    }

    public func cadenceTitle(for activity: ThemeActivity) -> String {
        switch activity.grain {
        case .day: String(appLocalized: "Votes on these topics per day")
        case .week: String(appLocalized: "Votes on these topics per week")
        }
    }

    public func title(for period: ThemeActivity.Period, in activity: ThemeActivity) -> String {
        switch activity.grain {
        case .day:
            period.start.formatted(
                .dateTime.weekday(.abbreviated).day().month(.abbreviated).locale(.app))
        case .week:
            String(
                appLocalized:
                    "Week of \(period.start.formatted(.dateTime.day().month(.abbreviated).locale(.app)))"
            )
        }
    }
}
