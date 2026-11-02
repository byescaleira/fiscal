import FeatureCore
import FiscalDomain
import Foundation

public struct ProfileSummaryFact: Identifiable, Equatable, Sendable {
    public let id: String
    public let text: String
    public let source: String?
    public let chapter: ProfileChapter
}

extension ProfileModel {
    public static let summaryLimit = 4

    public var summary: [ProfileSummaryFact] {
        guard let profile else { return [] }
        let numbers = profile.numbers
        let legislative = [
            attendanceFact(numbers.attendance), proposalsFact(numbers.proposals),
            quotaFact(numbers.quotaCents), electionFact(numbers.lastElectionVotes),
            votesFact(numbers.votes), assetsFact(numbers.assetsCents),
            campaignFact(numbers.campaignRevenueCents),
        ]
        let executive = [
            electionFact(numbers.lastElectionVotes), assetsFact(numbers.assetsCents),
            campaignFact(numbers.campaignRevenueCents),
        ]
        let available = Set(chapters)
        return Array(
            (profile.office.isLegislative ? legislative : executive).compactMap(\.self)
                .filter { available.contains($0.chapter) }
                .prefix(Self.summaryLimit))
    }

    public var numbersExplanation: Explanation? {
        guard let numbers = profile?.numbers else { return nil }
        let explanation = Explanation.term(numbers)
        return explanation.isEmpty ? nil : explanation
    }

    private func attendanceFact(_ attendance: Profile.Attendance?) -> ProfileSummaryFact? {
        guard let attendance, attendance.eligible > 0 else { return nil }
        let share = PublicFormat.percent(attendance.fraction)
        let present = PublicFormat.number(attendance.present)
        let eligible = PublicFormat.number(attendance.eligible)
        return fact(
            "attendance",
            String(appLocalized: "Attended \(share) of the sessions (\(present) of \(eligible))"),
            kind: "attendance", chapter: .votes)
    }

    private func proposalsFact(_ count: Int?) -> ProfileSummaryFact? {
        count.map {
            fact(
                "proposals", String(appLocalized: "Presented \($0) bills in the term"),
                kind: "proposals", chapter: .proposals)
        }
    }

    private func quotaFact(_ cents: Int?) -> ProfileSummaryFact? {
        cents.map {
            let value = PublicFormat.compactMoney(cents: $0)
            return fact(
                "quota", String(appLocalized: "Used \(value) of the office allowance"),
                kind: "expenses", chapter: .money)
        }
    }

    private func electionFact(_ count: Int?) -> ProfileSummaryFact? {
        count.map {
            let value = PublicFormat.number($0)
            return fact(
                "election", String(appLocalized: "Received \(value) votes in the last election"),
                kind: "campaigns", chapter: .origin)
        }
    }

    private func votesFact(_ count: Int?) -> ProfileSummaryFact? {
        count.map {
            let value = PublicFormat.number($0)
            return fact(
                "votes", String(appLocalized: "Took part in \(value) recorded votes"),
                kind: "votes", chapter: .votes)
        }
    }

    private func assetsFact(_ cents: Int?) -> ProfileSummaryFact? {
        cents.map {
            let value = PublicFormat.compactMoney(cents: $0)
            return fact(
                "assets", String(appLocalized: "Declared \(value) in assets"),
                kind: "assets", chapter: .origin)
        }
    }

    private func campaignFact(_ cents: Int?) -> ProfileSummaryFact? {
        cents.map {
            let value = PublicFormat.compactMoney(cents: $0)
            return fact(
                "campaign", String(appLocalized: "Raised \(value) for the campaign"),
                kind: "campaigns", chapter: .origin)
        }
    }

    private func fact(
        _ id: String, _ text: String, kind: String, chapter: ProfileChapter
    ) -> ProfileSummaryFact {
        ProfileSummaryFact(id: id, text: text, source: sourceName(for: kind), chapter: chapter)
    }
}
