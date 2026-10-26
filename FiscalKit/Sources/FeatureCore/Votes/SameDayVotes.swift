import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public enum SameDayVotes {
    public static let symbol = "square.stack"

    public static func mark(_ vote: VoteSummary, today: CalendarDay) -> String? {
        let count = vote.sameDayCount
        guard count > 0 else { return nil }
        let isToday = vote.date == today
        switch (count, isToday) {
        case (1, true): return String(appLocalized: "+1 vote on this bill today")
        case (1, false): return String(appLocalized: "+1 vote on this bill that day")
        case (_, true): return String(appLocalized: "+\(count) votes on this bill today")
        default: return String(appLocalized: "+\(count) votes on this bill that day")
        }
    }
}

public struct SameDayVotesMark: View {
    private let vote: VoteSummary
    private let today: CalendarDay

    public init(vote: VoteSummary, now: Date = .now) {
        self.vote = vote
        today = CalendarDay(now)
    }

    public var body: some View {
        if let text = SameDayVotes.mark(vote, today: today) {
            Label {
                Text(verbatim: text)
            } icon: {
                Image(systemName: SameDayVotes.symbol)
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
    }
}
