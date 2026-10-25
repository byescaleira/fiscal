import FeatureCore
import FiscalDomain
import Foundation
import Observation

@MainActor @Observable
public final class ProfileModel {
    public struct Fact: Identifiable, Equatable {
        public let id: String
        public let title: String
        public let value: String
    }

    public let slug: String
    public private(set) var profile: Profile?
    public private(set) var isFollowing = false
    public private(set) var phase: PublicDataPhase = .idle
    public var error: FiscalError?
    @ObservationIgnored private let service: (any PublicDataService)?
    @ObservationIgnored private let follows: (any FollowRepository)?
    @ObservationIgnored private let now: @Sendable () -> Date

    public init(
        slug: String, service: (any PublicDataService)?, follows: (any FollowRepository)? = nil,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.slug = slug
        self.service = service
        self.follows = follows
        self.now = now
    }

    public var isEmpty: Bool { profile == nil }

    public var canFollow: Bool { follows != nil && profile != nil }

    public var title: String { profile?.name ?? String(appLocalized: "Profile") }

    public var subtitle: String? {
        guard let profile else { return nil }
        let place = profile.uf == "br" ? "" : " · \(profile.uf.uppercased())"
        return "\(profile.office.title) · \(profile.party)\(place) · \(profile.status.title)"
    }

    public var facts: [Fact] {
        guard let numbers = profile?.numbers else { return [] }
        return [
            Fact(
                id: "attendance", title: String(appLocalized: "Attendance"),
                value: PublicFormat.percent(numbers.attendance?.fraction)),
            Fact(
                id: "proposals", title: String(appLocalized: "Proposals"),
                value: PublicFormat.number(numbers.proposals)),
            Fact(
                id: "votes", title: String(appLocalized: "Votes"),
                value: PublicFormat.number(numbers.votes)),
            Fact(
                id: "quota", title: String(appLocalized: "Office allowance"),
                value: PublicFormat.money(cents: numbers.quotaCents)),
            Fact(
                id: "salary", title: String(appLocalized: "Salary"),
                value: PublicFormat.money(cents: profile?.salary?.monthlyCents)),
            Fact(
                id: "assets", title: String(appLocalized: "Declared assets"),
                value: PublicFormat.money(cents: numbers.assetsCents)),
        ]
    }

    public var sources: [Source] { profile?.sources ?? [] }

    public func load() async {
        if profile == nil { phase = .loading }
        phase = await PublicDataPhase.settle(after: phase) {
            guard let service else { throw PublicDataError.unavailable }
            profile = try await service.profile(slug: slug)
            isFollowing = (try? await follows?.isFollowing(slug: slug)) ?? false
        }
    }

    public func toggleFollow() async {
        guard let follows, let card = profile?.card else { return }
        do {
            if isFollowing {
                try await follows.unfollow(slug: slug)
            } else {
                try await follows.follow(card, at: now())
            }
            isFollowing.toggle()
        } catch {
            self.error = .onSave
        }
    }
}
