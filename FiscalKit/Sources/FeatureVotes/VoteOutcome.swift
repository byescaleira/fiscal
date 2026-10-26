import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public enum VoteOutcome: Equatable, Sendable {
    case approved, rejected, symbolic, pending

    public init(_ vote: VoteSummary) {
        self.init(approved: vote.approved, nominal: vote.nominal)
    }

    public init(approved: Bool?, nominal: Bool) {
        switch approved {
        case true?: self = .approved
        case false?: self = .rejected
        case nil: self = nominal ? .pending : .symbolic
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
    public static func segments(_ tally: VoteSummary.Tally) -> [TallyChart.Segment] {
        [
            TallyChart.Segment(
                id: BallotChoice.yes.id, title: BallotChoice.yes.title,
                value: Double(tally.yes ?? 0), color: .voteYes),
            TallyChart.Segment(
                id: BallotChoice.no.id, title: BallotChoice.no.title,
                value: Double(tally.no ?? 0), color: .voteNo),
            TallyChart.Segment(
                id: BallotChoice.abstain.id, title: String(appLocalized: "Others"),
                value: Double(tally.others ?? 0), color: .voteAbstain),
        ]
    }

    public static func label(_ tally: VoteSummary.Tally) -> String {
        String(
            appLocalized:
                "Yes \(PublicFormat.number(tally.yes)), no \(PublicFormat.number(tally.no)), other \(PublicFormat.number(tally.others))"
        )
    }
}
