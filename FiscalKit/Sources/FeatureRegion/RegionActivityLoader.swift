import FeatureCore
import FiscalDomain
import Foundation

struct RegionActivityLoader: Sendable {
    static let voteLimit = 3
    static let voteScan = 5
    static let highlightLimit = 2

    let service: any PublicDataService

    func load(
        uf: String, region: Set<String>, executive: [String], seats: [House: Int]
    ) async -> RegionActivity {
        async let list = try? service.highlights()
        async let votes = votes(uf: uf, seats: seats)
        async let people = people(executive)
        let (highlights, found, leads) = await (list, votes, people)
        var activity = RegionActivity()
        activity.votes = found.map(\.vote)
        activity.actions = leads.actions
        activity.mandates = leads.mandates
        activity.method = highlights?.method
        let picked = Self.pick(
            highlights?.items ?? [], region: region, voteIDs: Set(found.map(\.vote.id)))
        activity.highlights = picked.highlights
        activity.highlightsAreNational = picked.isNational
        var seen = Set<String>()
        activity.sources = ((highlights?.sources ?? []) + found.flatMap(\.sources))
            .filter { seen.insert($0.id).inserted }
        return activity
    }

    static func pick(_ items: [Highlight], region: Set<String>, voteIDs: Set<String>)
        -> (highlights: [Highlight], isNational: Bool)
    {
        let items = items.filter { !($0.kind == .vote && voteIDs.contains($0.route)) }
        var people = Set<String>()
        let regional = items.filter { item in
            guard let slug = item.person?.slug, region.contains(slug) else { return false }
            return people.insert(slug).inserted
        }
        let chosen = Array(
            (regional.isEmpty ? Array(items.prefix(1)) : regional).prefix(Self.highlightLimit))
        return (chosen, regional.isEmpty && !chosen.isEmpty)
    }

    private struct Found: Sendable {
        let vote: RegionVote
        let sources: [Source]
    }

    private func votes(uf: String, seats: [House: Int]) async -> [Found] {
        let recent = (try? await service.recentVotes()) ?? []
        let candidates = Array(VoteDeck.ordered(recent).filter(\.nominal).prefix(Self.voteScan))
        let details = await withTaskGroup(of: (Int, VoteDetail?).self) { group in
            for (index, vote) in candidates.enumerated() {
                group.addTask { [service] in (index, try? await service.vote(id: vote.id)) }
            }
            var found: [Int: VoteDetail] = [:]
            for await (index, detail) in group { found[index] = detail }
            return found
        }
        return candidates.indices.compactMap { index -> Found? in
            guard let detail = details[index],
                let vote = RegionVote(
                    detail: detail, uf: uf, seats: seats[detail.vote.house] ?? 0)
            else { return nil }
            return Found(vote: vote, sources: detail.sources)
        }
        .prefix(Self.voteLimit)
        .map(\.self)
    }

    private func people(
        _ slugs: [String]
    ) async -> (actions: [String: ActionItem], mandates: [String: Profile.Mandate]) {
        await withTaskGroup(of: (String, ActionItem?, Profile.Mandate?).self) { group in
            for slug in Set(slugs) {
                group.addTask { [service] in
                    async let actions = try? service.actions(slug: slug)
                    async let profile = try? service.profile(slug: slug)
                    let lead = (await actions)?.items.max { lhs, rhs in
                        (lhs.weight, lhs.date) < (rhs.weight, rhs.date)
                    }
                    return (slug, lead, (await profile)?.mandate)
                }
            }
            var actions: [String: ActionItem] = [:]
            var mandates: [String: Profile.Mandate] = [:]
            for await (slug, lead, mandate) in group {
                actions[slug] = lead
                mandates[slug] = mandate
            }
            return (actions, mandates)
        }
    }
}
