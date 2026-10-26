import FiscalDomain
import Foundation

struct InvestigationEvidence: Sendable {
    var profiles: [String: Profile] = [:]
    var facts: FactIndex?
    var votes: [String: VoteDetail] = [:]
    var checks: [String: FactCheckList] = [:]
    var checked: Set<String> = []
    var contexts: [String: PersonContext] = [:]
    var recent: [VoteSummary] = []
    var updatedAt: Date?
    var failures = 0
    var attempts = 0
    var error: PublicDataError?

    var isPartial: Bool { failures > 0 }
}

struct InvestigationEngine: Sendable {
    private enum Loaded: Sendable {
        case profile(String, Profile)
        case vote(String, VoteDetail)
        case checks(String, FactCheckList?)
        case context(String, PersonContext?)
        case facts(FactIndex?)
        case failed(PublicDataError)
    }

    let service: any PublicDataService

    func evidence(for pieces: [InvestigationPiece], recent: [VoteSummary]) async throws
        -> InvestigationEvidence
    {
        var evidence = InvestigationEvidence()
        evidence.recent = recent
        let people = pieces.people
        let votes = pieces.votes
        let checks = pieces.compactMap { piece -> String? in
            if case .checks(let card) = piece { return card.slug }
            return nil
        }
        let contexts = pieces.compactMap { piece -> String? in
            if case .context(let card) = piece { return card.slug }
            return nil
        }
        let service = service
        let results = await withTaskGroup(of: Loaded.self) { group in
            for card in people {
                group.addTask {
                    await Self.run {
                        .profile(card.slug, try await service.profile(slug: card.slug))
                    }
                }
            }
            for vote in votes {
                group.addTask {
                    await Self.run { .vote(vote.id, try await service.vote(id: vote.id)) }
                }
            }
            for slug in checks {
                group.addTask {
                    await Self.run { .checks(slug, try await service.checks(slug: slug)) }
                }
            }
            for slug in contexts {
                group.addTask {
                    await Self.run { .context(slug, try await service.context(slug: slug)) }
                }
            }
            if !people.isEmpty {
                group.addTask { await Self.run { .facts(try await service.facts()) } }
            }
            var all: [Loaded] = []
            for await result in group { all.append(result) }
            return all
        }
        evidence.attempts = results.count
        for result in results {
            switch result {
            case .profile(let slug, let profile): evidence.profiles[slug] = profile
            case .vote(let id, let detail): evidence.votes[id] = detail
            case .checks(let slug, let list):
                evidence.checked.insert(slug)
                evidence.checks[slug] = list
            case .context(let slug, let context): evidence.contexts[slug] = context
            case .facts(let facts): evidence.facts = facts
            case .failed(let error):
                evidence.failures += 1
                evidence.error = evidence.error ?? error
            }
        }
        if evidence.attempts > 0, evidence.failures == evidence.attempts,
            let error = evidence.error,
            error != .notFound
        {
            throw error
        }
        evidence.updatedAt =
            evidence.facts?.generatedAt
            ?? evidence.profiles.values
            .flatMap(\.sources).compactMap(\.updatedAt).max()
        return evidence
    }

    private static func run(_ work: @Sendable () async throws -> Loaded) async -> Loaded {
        do {
            return try await work()
        } catch {
            return .failed(error as? PublicDataError ?? .unavailable)
        }
    }
}
