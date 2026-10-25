import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public enum VoteOutcome: Equatable, Sendable {
    case approved, rejected, symbolic, pending

    public init(_ vote: VoteSummary) {
        switch vote.approved {
        case true?: self = .approved
        case false?: self = .rejected
        case nil: self = vote.nominal ? .pending : .symbolic
        }
    }

    public var title: String {
        switch self {
        case .approved: String(appLocalized: "Approved")
        case .rejected: String(appLocalized: "Rejected")
        case .symbolic: String(appLocalized: "Voice vote")
        case .pending: String(appLocalized: "No result yet")
        }
    }

    public var symbol: String {
        switch self {
        case .approved: "checkmark.seal"
        case .rejected: "xmark.seal"
        case .symbolic: "speaker.wave.2"
        case .pending: "hourglass"
        }
    }

    public var color: Color {
        switch self {
        case .approved: BallotChoice.yes.color
        case .rejected: BallotChoice.no.color
        case .symbolic, .pending: .secondary
        }
    }
}

public enum VoteTally {
    public static func segments(_ tally: VoteSummary.Tally) -> [TallyBar.Segment] {
        [
            TallyBar.Segment(
                id: BallotChoice.yes.id, value: Double(tally.yes ?? 0), color: .voteYes),
            TallyBar.Segment(id: BallotChoice.no.id, value: Double(tally.no ?? 0), color: .voteNo),
            TallyBar.Segment(
                id: BallotChoice.abstain.id, value: Double(tally.others ?? 0),
                color: .voteAbstain),
        ]
    }

    public static func label(_ tally: VoteSummary.Tally) -> String {
        String(
            appLocalized:
                "Yes \(PublicFormat.number(tally.yes)), no \(PublicFormat.number(tally.no)), other \(PublicFormat.number(tally.others))"
        )
    }
}
