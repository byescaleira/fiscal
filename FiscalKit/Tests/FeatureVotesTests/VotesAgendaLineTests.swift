import FeatureCore
import FiscalData
import FiscalDomain
import Foundation
import Testing

@testable import FeatureVotes

private struct AgendaOnly: PublicDataService {
    let published: Agenda

    func meta() async throws -> PublicMeta { throw PublicDataError.notFound }
    func people() async throws -> [PersonCard] { [] }
    func places() async throws -> [Place] { [] }
    func representatives(uf: String) async throws -> PlaceRepresentatives {
        throw PublicDataError.notFound
    }
    func profile(slug: String) async throws -> Profile { throw PublicDataError.notFound }
    func votes(slug: String, year: Int) async throws -> PublicList<PersonVote> {
        throw PublicDataError.notFound
    }
    func proposals(slug: String, year: Int) async throws -> PublicList<Proposal> {
        throw PublicDataError.notFound
    }
    func speeches(slug: String, year: Int) async throws -> PublicList<Speech> {
        throw PublicDataError.notFound
    }
    func expenses(slug: String, year: Int) async throws -> ExpenseList {
        throw PublicDataError.notFound
    }
    func checks(slug: String) async throws -> FactCheckList? { nil }
    func recentVotes() async throws -> [VoteSummary] { [] }
    func vote(id: String) async throws -> VoteDetail { throw PublicDataError.notFound }
    func agenda() async throws -> Agenda { published }
    func money() async throws -> MoneyOverview { throw PublicDataError.notFound }
    func today() async throws -> TodayDigest { throw PublicDataError.notFound }
}

@MainActor
struct VotesAgendaLineTests {
    private let now = Date(timeIntervalSince1970: 1_792_917_720)
    private let item = AgendaItem(
        proposition: "PL 1/2026", summary: "Texto", status: nil, themes: [], url: nil)

    private func model(_ agenda: Agenda) async -> VotesModel {
        let now = now
        let votes = VotesModel(service: AgendaOnly(published: agenda), now: { now })
        await votes.load()
        return votes
    }

    private func day(_ offset: Double) -> Date { now.addingTimeInterval(offset * 86_400) }

    @Test func aFutureSessionWithItsAgendaShowsTheDateAndTheCount() async throws {
        let next = day(2)
        let votes = await model(
            Agenda(
                date: CalendarDay(next),
                houses: [
                    .init(
                        house: .camara, inSession: false, nextSession: next, items: [item, item]),
                    .init(house: .senado, inSession: false, nextSession: day(3), items: []),
                ]))
        let line = try #require(votes.agendaLine)
        #expect(line == AgendaLine(status: .next(next), houses: [.camara], itemCount: 2))
        #expect(votes.agendaHouses.map(\.house) == [.camara])
        let text = next.formatted(
            Date.FormatStyle(locale: .app).weekday(.abbreviated).day(.twoDigits).month(.twoDigits))
        #expect(votes.agendaLineTitle(line) == String(appLocalized: "Next session: \(text)"))
        #expect(votes.agendaLineDetail(line).contains(VotesModel.shortHouse(.camara)))
    }

    @Test func aSessionUnderWaySaysSoWithItsItems() async throws {
        let votes = await model(
            Agenda(
                date: CalendarDay(now),
                houses: [
                    .init(house: .senado, inSession: true, nextSession: nil, items: [item])
                ]))
        let line = try #require(votes.agendaLine)
        #expect(line == AgendaLine(status: .inSession, houses: [.senado], itemCount: 1))
        #expect(votes.agendaLineTitle(line) == String(appLocalized: "In session"))
    }

    @Test func aPastAgendaWithoutSessionsAheadShowsNothing() async {
        let votes = await model(
            Agenda(
                date: CalendarDay(day(-5)),
                houses: [
                    .init(house: .camara, inSession: true, nextSession: day(-1), items: [item]),
                    .init(house: .senado, inSession: false, nextSession: nil, items: [item]),
                ]))
        #expect(votes.agendaLine == nil)
        #expect(votes.agendaHouses.isEmpty)
        #expect(votes.isEmpty)
    }

    @Test func aPastAgendaNeverLendsItsItemsToTheNextSession() async throws {
        let next = day(2)
        let votes = await model(
            Agenda(
                date: CalendarDay(day(-5)),
                houses: [
                    .init(house: .camara, inSession: false, nextSession: next, items: [item]),
                    .init(house: .senado, inSession: false, nextSession: day(-5), items: []),
                ]))
        let line = try #require(votes.agendaLine)
        #expect(line == AgendaLine(status: .next(next), houses: [.camara], itemCount: 0))
        #expect(votes.agendaHouses.isEmpty)
        #expect(votes.agendaLineDetail(line) == VotesModel.shortHouse(.camara))
    }

    @Test func todaysItemsDoNotCountForASessionOnAnotherDay() async throws {
        let next = day(2)
        let votes = await model(
            Agenda(
                date: CalendarDay(now),
                houses: [
                    .init(house: .camara, inSession: false, nextSession: next, items: [item])
                ]))
        #expect(try #require(votes.agendaLine).itemCount == 0)
    }
}
