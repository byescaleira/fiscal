import FiscalDomain
import Foundation
import Testing

struct PublicDataDecodingTests {
    private func decode<Value: Decodable>(_ type: Value.Type, _ json: String) throws -> Value {
        try PublicDataCoding.decoder().decode(type, from: Data(json.utf8))
    }

    @Test func readsASourceWithAnOffsetDate() throws {
        let source = try decode(
            Source.self,
            #"{ "id": "camara", "name": "Câmara dos Deputados", "url": "https://dadosabertos.camara.leg.br", "updatedAt": "2026-10-25T05:42:00-03:00" }"#
        )
        #expect(source.id == "camara")
        #expect(source.url?.host() == "dadosabertos.camara.leg.br")
        #expect(source.updatedAt == Date(timeIntervalSince1970: 1_792_917_720))
    }

    @Test func readsDateOnlyTimestampsAndNulls() throws {
        let source = try decode(
            Source.self,
            #"{ "id": "ibge", "name": "IBGE", "url": null, "updatedAt": "2026-10-25" }"#)
        #expect(source.url == nil)
        let day = try #require(source.updatedAt)
        #expect(CalendarDay(day) == CalendarDay(year: 2_026, month: 10, day: 25))
    }

    @Test func readsTheSearchIndex() throws {
        let people = try decode(
            [PersonCard].self,
            #"[{ "slug": "tabata-amaral", "name": "Tabata Amaral", "office": "federalDeputy", "uf": "sp", "party": "PSB", "photo": null, "status": "inOffice" }, { "slug": "lula", "name": "Lula", "office": "president", "uf": "br", "party": "PT", "photo": "https://example.test/lula.jpg", "status": "inOffice" }]"#
        )
        #expect(people.map(\.office) == [.federalDeputy, .president])
        #expect(people.first?.photo == nil)
        #expect(people.last?.photo?.lastPathComponent == "lula.jpg")
    }

    @Test func rejectsAnOfficeOutsideTheContract() {
        #expect(throws: DecodingError.self) {
            try decode(
                PersonCard.self,
                #"{ "slug": "x", "name": "X", "office": "mayor", "uf": "sp", "party": "PT", "photo": null, "status": "inOffice" }"#
            )
        }
    }

    @Test func readsTheRepresentativesOfAState() throws {
        let place = try decode(
            PlaceRepresentatives.self,
            #"{ "uf": "sp", "name": "São Paulo", "groups": [{ "level": "state", "office": "senator", "title": "Senadores", "people": [] }], "sources": [] }"#
        )
        #expect(place.groups.first?.level == .state)
        #expect(place.groups.first?.office == .senator)
    }

    @Test func readsAProfileWithMissingData() throws {
        let profile = try decode(Profile.self, PublicDataFixtures.stateDeputyProfile)
        #expect(profile.office == .stateDeputy)
        #expect(profile.status == .electedAwaiting)
        #expect(profile.contact == nil)
        #expect(profile.salary == nil)
        #expect(profile.numbers.attendance == nil)
        #expect(profile.numbers.proposals == nil)
        #expect(profile.numbers.assetsCents == 125_000_000)
        #expect(profile.mandate?.start == CalendarDay(year: 2_027, month: 2, day: 1))
        #expect(profile.themes.map(\.key) == [.education, .health])
        #expect(profile.coverage(of: "votes") == .notPublished)
        #expect(profile.coverage(of: "speeches") == .notLoaded)
        #expect(profile.card.slug == profile.slug)
    }

    @Test func readsTheExpensesOfAYear() throws {
        let expenses = try decode(ExpenseList.self, PublicDataFixtures.expenses)
        #expect(expenses.totalCents == 1_250_075)
        #expect(expenses.items.first?.document == nil)
        #expect(expenses.byMonth.map(\.month) == [3])
        #expect(expenses.byCategory.first?.count == 1)
    }

    @Test func readsAVoteDetailFlattenedOverTheSummary() throws {
        let detail = try decode(VoteDetail.self, PublicDataFixtures.voteDetail)
        #expect(detail.id == "camara-2416587")
        #expect(detail.vote.house == .camara)
        #expect(detail.vote.date == CalendarDay(year: 2_026, month: 10, day: 21))
        #expect(detail.vote.tally.total == 470)
        #expect(detail.quorum == 257)
        #expect(detail.parties.first?.party == "PL")
        #expect(detail.people.first?.vote == "Sim")
        let encoded = try PublicDataCoding.encoder().encode(detail)
        #expect(try PublicDataCoding.decoder().decode(VoteDetail.self, from: encoded) == detail)
    }

    @Test func readsTheAgendaAndTheDigest() throws {
        let agenda = try decode(
            Agenda.self,
            #"{ "date": "2026-10-25", "houses": [{ "house": "senado", "inSession": false, "nextSession": "2026-10-27T14:00:00-03:00", "items": [] }] }"#
        )
        #expect(agenda.houses.first?.house == .senado)
        #expect(agenda.houses.first?.nextSession != nil)
        let digest = try decode(
            TodayDigest.self,
            #"{ "date": "2026-10-25", "events": [{ "kind": "race", "title": "Apuração", "summary": "Direto do TSE", "themes": ["politica"], "ref": "presidente-br" }], "sources": [] }"#
        )
        #expect(digest.events.first?.kind == .race)
        #expect(digest.events.first?.themes == [.politics])
    }

    @Test func readsTheMoneyOverviewWithoutRevenue() throws {
        let money = try decode(MoneyOverview.self, PublicDataFixtures.money)
        #expect(money.salaries.first?.office == .federalDeputy)
        #expect(money.campaigns.byOrigin.count == 1)
        #expect(money.revenue == nil)
    }
}
