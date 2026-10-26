import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public enum SameDayVotes {
    public static let symbol = "square.stack"

    public static func mark(_ vote: VoteSummary, today: CalendarDay) -> String? {
        let count = vote.sameDayCount
        guard count > 0 else { return nil }
        return vote.date == today
            ? String(appLocalized: "+\(count) votes on this bill today")
            : String(appLocalized: "+\(count) votes on this bill that day")
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
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
    }
}
