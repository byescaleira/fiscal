import FiscalData
import FiscalDomain
import Foundation
import Testing

@testable import FeatureToday

@MainActor
struct TodayModelTests {
    private let now = Date(timeIntervalSince1970: 1_792_917_720)

    private func model(
        _ scenario: PublicDataScenario = .normal, stance: PoliticalStance? = nil,
        races: RaceScenario? = nil, follows: PublicDataScenario? = nil
    ) -> TodayModel {
        TodayModel(
            service: ShowcasePublicData(scenario: scenario, now: now),
            lens: ShowcaseLensRepository(stance: stance),
            races: races.map(ShowcaseLiveResults.init(scenario:)),
            follows: follows.map { ShowcaseFollowRepository(scenario: $0, now: now) })
    }

    @Test func loadsTheDigestOfTheDay() async {
        let model = TodayModel(service: ShowcasePublicData(scenario: .normal, now: now))
        #expect(model.phase == .idle)
        await model.load()
        #expect(model.phase == .loaded)
        #expect(!model.isEmpty)
        #expect(model.events.first?.kind == .vote)
        #expect(!model.sources.isEmpty)
        #expect(model.digestSource != nil)
        #expect(model.agendaSource != nil)
        #expect(model.recentSource != nil)
    }

    @Test func theLensOrdersTheDayWithoutHidingAnything() async throws {
        let repositories = try FiscalDatabase.open(inMemory: true).repositories
        try await repositories.lens.save(Lens(themes: [.education, .politics, .health]))
        let model = TodayModel(
            service: ShowcasePublicData(scenario: .normal, now: now), lens: repositories.lens)
        await model.load()
        let kinds = model.events.map(\.kind)
        #expect(kinds == [.session, .race, .vote, .vote])
        #expect(model.lens?.themes.first == .education)
        #expect(model.briefing.first?.isLensPick == true)
        #expect(model.briefing.count == 4)
    }

    @Test func eachSideSeesItsTopicsFirstButTheSameFacts() async {
        let right = model(stance: .right)
        let left = model(stance: .left)
        await right.load()
        await left.load()
        #expect(right.stance == .right)
        #expect(right.lead?.value.themes.contains(.taxes) == true)
        #expect(left.lead?.value.themes.contains(.rights) == true)
        #expect(Set(right.events) == Set(left.events))
        #expect(right.recentVotes == left.recentVotes)
    }

    @Test func impartialTakesTurnsAndShowsTheBadge() async {
        let model = model(stance: .impartial)
        await model.load()
        #expect(model.mode == .alternating)
        #expect(model.stance == .impartial)
        #expect(model.lensLine != nil)
    }

    @Test func withoutALensTheInviteShowsAndNothingIsMarked() async {
        let model = model()
        await model.load()
        #expect(model.hasCheckedLens)
        #expect(model.lens == nil)
        #expect(model.stance == nil)
        #expect(model.briefing.allSatisfy { !$0.isLensPick })
    }

    @Test func theLeadVoteIsNotRepeatedInRecentVotes() async throws {
        let model = model()
        await model.load()
        let lead = try #require(model.lead)
        let vote = try #require(model.leadVote(for: lead.value))
        #expect(!model.recent.contains(vote))
        #expect(model.recent.count == TodayModel.recentLimit)
        #expect(model.route(for: lead.value) == .vote(id: vote.id))
        #expect(model.shareSubject(for: lead.value) == .vote(id: vote.id))
    }

    @Test func aLiveRaceTakesTheCardAndLeavesTheSummary() async {
        let model = model(races: .close)
        await model.load()
        #expect(model.liveBoard?.race.id == "presidente-br")
        #expect(model.liveBoard?.others == 6)
        #expect(!model.briefing.contains { $0.value.kind == .race })
        #expect(model.events.contains { $0.kind == .race })
    }

    @Test func noElectionNoCard() async {
        let finished = model(races: .finished)
        await finished.load()
        #expect(finished.liveBoard == nil)
        #expect(finished.briefing.contains { $0.value.kind == .race })
        await finished.watchRaces()
        let quiet = model()
        await quiet.load()
        #expect(quiet.liveBoard == nil)
    }

    @Test func aLostConnectionKeepsTheLastNumbersMarkedAsStale() async {
        let model = model(races: .offline)
        await model.load()
        #expect(model.liveBoard?.isStale == false)
        await model.refreshRaces()
        #expect(model.racesOffline)
        #expect(model.liveBoard?.isStale == true)
    }

    @Test func followedPeopleShowHowTheyVotedInTheirHouse() async throws {
        let model = model(follows: .normal)
        await model.load()
        let people = model.representatives
        #expect(people.count == TodayModel.representativesLimit)
        #expect(model.moreFollowed == 1)
        #expect(people.map(\.card.name) == people.map(\.card.name).sorted())
        let senator = try #require(people.first { $0.card.office == .senator })
        #expect(senator.vote?.house == .senado)
        #expect(senator.ballot != nil)
        let deputy = try #require(people.first { $0.card.office == .federalDeputy })
        #expect(deputy.vote?.house == .camara)
        #expect(deputy.ballot != nil)
    }

    @Test func peopleWhoDoNotVoteOnTheFloorShowNoBallot() async {
        let model = model(follows: .normal)
        await model.load()
        let governor = TodayModel.house(for: .governor)
        #expect(governor == nil)
        #expect(TodayModel.house(for: .stateDeputy) == nil)
        #expect(TodayModel.house(for: .federalDeputy) == .camara)
    }

    @Test func anEmptyDayIsHonest() async {
        let model = model(.empty)
        await model.load()
        #expect(model.phase == .loaded)
        #expect(model.isEmpty)
        #expect(model.lead == nil)
        #expect(model.houses.isEmpty)
        #expect(model.recent.isEmpty)
        #expect(model.agendaSource == nil)
        #expect(model.representatives.isEmpty)
    }

    @Test func reportsWhyTheDayDidNotLoad() async {
        let offline = model(.offline)
        await offline.load()
        #expect(offline.phase == .failed(.offline))
        #expect(!offline.hasLoadedDigest)
        #expect(offline.notice == nil)
        let unavailable = model(.unavailable)
        await unavailable.load()
        #expect(unavailable.phase == .failed(.unavailable))
        let missing = TodayModel(service: nil)
        await missing.load()
        #expect(missing.phase.error == .unavailable)
    }

    @Test func longNamesStillLoad() async {
        let model = model(.longNames, follows: .longNames)
        await model.load()
        #expect(model.phase == .loaded)
        #expect(model.representatives.contains { $0.card.name.count > 40 })
    }
}
