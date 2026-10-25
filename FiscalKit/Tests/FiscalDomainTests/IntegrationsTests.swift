import FiscalDomain
import Foundation
import Testing

struct HomePlaceTests {
    @Test(arguments: [
        ("sp", "sp"), (" SP ", "sp"), ("3550308", "sp"), ("5300108", "df"), ("1100015", "ro"),
        ("4314902", "rs"),
    ])
    func resolvesTheStateOfAPlace(code: String, uf: String) {
        #expect(HomePlace.uf(fromPlaceCode: code) == uf)
    }

    @Test(arguments: ["", "br", "xx", "9900000", "35503", "abcdefg"])
    func ignoresWhatIsNotAState(code: String) {
        #expect(HomePlace.uf(fromPlaceCode: code) == nil)
    }

    @Test func listsTheTwentySevenStates() {
        #expect(HomePlace.states.count == 27)
        #expect(Set(HomePlace.states).count == 27)
    }

    @Test func savesTheStateOnlyWhenItChanges() throws {
        let suite = "fiscal.tests.homePlace.\(UUID().uuidString)"
        defer { UserDefaults().removePersistentDomain(forName: suite) }
        let place = HomePlace(suiteName: suite)
        #expect(place.uf == nil)
        #expect(place.save(uf: "3550308"))
        #expect(place.uf == "sp")
        #expect(!place.save(uf: "sp"))
        #expect(place.save(uf: nil))
        #expect(place.uf == nil)
        #expect(place.save(scenario: "normal"))
        #expect(place.scenario == "normal")
        #expect(!place.save(scenario: "normal"))
    }

    @Test func readsThePlacePickedInMine() throws {
        let suite = "fiscal.tests.mine.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(HomePlace.chosenUF(in: defaults) == nil)
        defaults.set("2927408", forKey: HomePlace.mineKey)
        #expect(HomePlace.chosenUF(in: defaults) == "ba")
    }
}

struct VoteBoardTests {
    static func vote(
        id: String = "camara-1", date: String = "2026-10-21", time: String? = "18:42",
        approved: Bool? = true, nominal: Bool = true, tally: VoteSummary.Tally
    ) -> VoteSummary {
        VoteSummary(
            id: id, house: .camara, date: CalendarDay(date) ?? CalendarDay(Date.now),
            time: time, proposition: "PL 1873/2026", kind: "Projeto de Lei",
            summary: "Altera a Lei nº 9.250.", plainSummary: "Muda uma lei.", themes: [.taxes],
            result: approved == nil ? nil : "Aprovado", approved: approved, nominal: nominal,
            tally: tally)
    }

    @Test func showsTheScoreAndShares() {
        let board = VoteBoard(Self.vote(tally: .init(yes: 300, no: 100, others: 100)))
        #expect(board.yesText == PublicFormat.number(300))
        #expect(board.scoreText == "\(PublicFormat.number(300)) × \(PublicFormat.number(100))")
        #expect(board.hasScore)
        #expect(board.yesShare == 0.6)
        #expect(board.noShare == 0.2)
        #expect(board.othersShare == 0.2)
        #expect(board.outcome == .approved)
        #expect(board.outcomeSymbol == "checkmark.seal")
        #expect(board.summary == "Muda uma lei.")
        #expect(board.url?.absoluteString == "fiscal://vote/camara-1")
    }

    @Test func showsADashWhenTheScoreIsMissing() {
        let board = VoteBoard(
            Self.vote(approved: nil, nominal: false, tally: .init(yes: nil, no: nil, others: nil)))
        #expect(board.yesText == PublicFormat.missing)
        #expect(board.noText == PublicFormat.missing)
        #expect(!board.hasScore)
        #expect(board.yesShare == 0)
        #expect(board.outcome == .unknown)
        #expect(board.outcomeTitle == PublicFormat.missing)
    }

    @Test func picksTheLatestRollCallVote() throws {
        let votes = [
            Self.vote(id: "a", date: "2026-10-20", tally: .init(yes: 1, no: 1, others: 0)),
            Self.vote(
                id: "b", date: "2026-10-22", time: "10:00", nominal: false,
                tally: .init(yes: nil, no: nil, others: nil)),
            Self.vote(
                id: "c", date: "2026-10-21", time: "09:00", tally: .init(yes: 2, no: 1, others: 0)),
            Self.vote(
                id: "d", date: "2026-10-21", time: "18:00", tally: .init(yes: 3, no: 1, others: 0)),
        ]
        let deck = try #require(VoteDeck(votes: votes))
        #expect(deck.headline.id == "d")
        #expect(deck.earlier.map(\.id) == ["b", "c", "a"])
        #expect(VoteDeck(votes: []) == nil)
    }
}

struct RepresentativesDigestTests {
    private func card(_ slug: String, _ name: String, _ office: Office) -> PersonCard {
        PersonCard(
            slug: slug, name: name, office: office, uf: "sp", party: "PSD", photo: nil,
            status: .inOffice)
    }

    @Test func featuresTheGovernorAndSenatorsInAlphabeticalOrder() {
        let place = PlaceRepresentatives(
            uf: "sp", name: "São Paulo",
            groups: [
                RepresentativeGroup(
                    level: .country, office: .president, title: "Presidente",
                    people: [card("p", "Pessoa Presidente", .president)]),
                RepresentativeGroup(
                    level: .state, office: .senator, title: "Senadores",
                    people: [
                        card("z", "Zélia Prado", .senator), card("b", "Bruno Lima", .senator),
                        card("m", "Marta Dias", .senator),
                    ]),
                RepresentativeGroup(
                    level: .state, office: .governor, title: "Governador",
                    people: [card("g", "Gil Souza", .governor)]),
                RepresentativeGroup(
                    level: .state, office: .federalDeputy, title: "Deputados federais",
                    people: [card("d1", "Ana", .federalDeputy), card("d2", "Beto", .federalDeputy)]),
            ],
            sources: [Source(id: "tse", name: "TSE", url: nil, updatedAt: nil)])
        let digest = RepresentativesDigest(place)
        #expect(digest.featured.map(\.slug) == ["g", "b", "m", "z"])
        #expect(digest.federalDeputies == 2)
        #expect(digest.stateDeputies == nil)
        #expect(digest.ufText == "SP")
        #expect(!digest.isEmpty)
        #expect(digest.sourceText.contains("TSE"))
    }

    @Test func isEmptyWithoutRepresentatives() {
        let digest = RepresentativesDigest(
            PlaceRepresentatives(uf: "ac", name: "", groups: [], sources: []))
        #expect(digest.isEmpty)
        #expect(digest.name == HomePlace.name(of: "ac"))
    }
}

struct WidgetScheduleTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo") ?? .gmt
        return calendar
    }

    private func date(_ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour)) ?? .now
    }

    @Test func refreshesHourlyDuringSessions() {
        let now = date(21, 15)
        #expect(WidgetSchedule.nextVotesRefresh(after: now, calendar: calendar) == now + 3_600)
    }

    @Test func waitsForTheMorningOutsideSessions() {
        #expect(
            WidgetSchedule.nextVotesRefresh(after: date(21, 23), calendar: calendar)
                == date(22, 8))
        #expect(
            WidgetSchedule.nextVotesRefresh(after: date(25, 15), calendar: calendar)
                == date(26, 8))
        #expect(
            WidgetSchedule.nextVotesRefresh(after: date(22, 5), calendar: calendar)
                == date(22, 8))
    }

    @Test func neverRefreshesEveryMinute() {
        let now = date(21, 10)
        #expect(
            WidgetSchedule.nextRepresentativesRefresh(after: now).timeIntervalSince(now) >= 3_600)
        #expect(WidgetSchedule.retry(after: now).timeIntervalSince(now) >= 3_600)
    }
}
