import FiscalDomain
import Foundation
import Testing

@testable import FeatureLiveResults

private actor FakeService: LiveResultsService {
    var result: Result<[Race], FiscalError>
    private(set) var followed: [String] = []
    private(set) var unfollowed: [String] = []

    init(_ result: Result<[Race], FiscalError>) { self.result = result }

    func races() async throws -> [Race] { try result.get() }

    func follow(raceID: String, pushToken: String, environment: PushEnvironment) async throws {
        followed.append("\(raceID):\(pushToken):\(environment.rawValue)")
    }

    func unfollow(pushToken: String) async throws { unfollowed.append(pushToken) }

    func set(_ result: Result<[Race], FiscalError>) { self.result = result }
}

@MainActor
private final class FakeActivities: RaceActivityTracking {
    var active: Set<String> = []
    var updated: [String] = []
    var fails = false
    var isAvailable: Bool { true }

    func activeRaceIDs() -> Set<String> { active }

    func start(_ race: Race, onToken: @escaping @MainActor (String) -> Void) throws {
        if fails { throw FiscalError.onSave }
        active.insert(race.id)
        onToken("abc123")
    }

    func resume(onToken: @escaping @MainActor (String, String) -> Void) {}

    func update(_ race: Race) async { updated.append(race.id) }

    func end(raceID: String) async -> [String] {
        active.remove(raceID)
        return ["abc123"]
    }
}

private func race(id: String = "presidente-br", counted: Int = 10, final: Bool = false) -> Race {
    Race(
        id: id, office: id.hasPrefix("presidente") ? .president : .governor,
        uf: String(id.suffix(2)), round: 2,
        sections: .init(total: 100, counted: counted, percent: Double(counted)),
        electorate: 1000, turnout: 500, votes: .init(valid: 400, blank: 50, null: 50, total: 500),
        candidates: [
            RaceCandidate(
                number: "13", name: "Ana", party: "AA", votes: 250, percent: 62.5, elected: final),
            RaceCandidate(
                number: "22", name: "Bia", party: "BB", votes: 150, percent: 37.5, elected: false),
        ],
        final: final, sourceGeneratedAt: "2026-10-25T18:00:00-03:00")
}

@MainActor
struct LiveResultsModelTests {
    @Test func loadsAndSplitsTheRaces() async {
        let service = FakeService(.success([race(), race(id: "governador-ac")]))
        let model = LiveResultsModel(
            service: service, activities: FakeActivities(), environment: .development)
        await model.refresh()
        #expect(model.hasLoaded)
        #expect(model.president?.id == "presidente-br")
        #expect(model.governors.map(\.id) == ["governador-ac"])
        #expect(!model.isOffline)
        #expect(!model.isWaiting)
    }

    @Test func waitsUntilTheCountStarts() async {
        let model = LiveResultsModel(
            service: FakeService(.success([race(counted: 0)])), activities: FakeActivities(),
            environment: .development)
        await model.refresh()
        #expect(model.isWaiting)
        #expect(model.statusText(model.races[0]) == "Starts at 5 PM Brasília time")
    }

    @Test func keepsTheLastNumbersWhenOffline() async {
        let service = FakeService(.success([race()]))
        let model = LiveResultsModel(
            service: service, activities: FakeActivities(), environment: .development)
        await model.refresh()
        await service.set(.failure(.onFetch))
        await model.refresh()
        #expect(model.isOffline)
        #expect(model.races.count == 1)
    }

    @Test func updatesFollowedActivitiesWithFreshNumbers() async {
        let activities = FakeActivities()
        activities.active = ["presidente-br"]
        let model = LiveResultsModel(
            service: FakeService(.success([race(), race(id: "governador-df")])),
            activities: activities,
            environment: .development)
        await model.toggle(race(id: "governador-df"))
        await model.refresh()
        #expect(activities.updated.sorted() == ["governador-df"])
    }

    @Test func followingRegistersThePushToken() async throws {
        let service = FakeService(.success([race()]))
        let activities = FakeActivities()
        let model = LiveResultsModel(
            service: service, activities: activities, environment: .production)
        await model.toggle(race())
        #expect(model.isFollowing(race()))
        try await Task.sleep(for: .milliseconds(100))
        #expect(await service.followed == ["presidente-br:abc123:production"])
        await model.toggle(race())
        #expect(!model.isFollowing(race()))
        #expect(await service.unfollowed == ["abc123"])
    }

    @Test func explainsWhenActivitiesAreOff() async {
        let activities = FakeActivities()
        activities.fails = true
        let model = LiveResultsModel(
            service: FakeService(.success([])), activities: activities, environment: .development)
        await model.toggle(race())
        #expect(model.error != nil)
        #expect(!model.isFollowing(race()))
    }

    @Test func describesTheResult() {
        let model = LiveResultsModel(
            service: nil, activities: FakeActivities(), environment: .development)
        #expect(!model.isConfigured)
        #expect(model.statusText(race(final: true)) == "Ana elected")
        #expect(model.statusText(race()) == "Counting")
    }
}
