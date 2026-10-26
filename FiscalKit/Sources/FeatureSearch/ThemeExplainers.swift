import FeatureCore
import FiscalDomain
import Foundation

extension SearchModel {
    public func barsExplanation(for activity: ThemeActivity) -> Explanation {
        Explanation.topicBars(
            activity.slices.map {
                Explanation.TopicCount(
                    title: $0.theme.title, count: $0.count, approved: $0.approved)
            }, total: activity.total)
    }

    public func cadenceExplanation(for activity: ThemeActivity) -> Explanation {
        let busiest = activity.periods.max { $0.count < $1.count }
        return Explanation.topicCadence(
            weekly: activity.grain == .week, average: activity.average,
            busiest: busiest.map { title(for: $0, in: activity) }, busiestCount: busiest?.count)
    }
}
