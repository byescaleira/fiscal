import FiscalDomain
import Foundation
import Testing

struct MemoryService: PublicDataService {
    var history: ElectionHistory?
    var timeline: PoliticalTimeline?
    var study: StudyCatalog?
    var cards: [PersonCard] = []
    var fails = false

    static let failing = MemoryService(fails: true)

    func electionHistory() async throws -> ElectionHistory? {
        if fails { throw PublicDataError.offline }
        return history
    }

    func politicalTimeline() async throws -> PoliticalTimeline? {
        if fails { throw PublicDataError.offline }
        return timeline
    }

    func studyCatalog() async throws -> StudyCatalog? {
        if fails { throw PublicDataError.offline }
        return study
    }

    func people() async throws -> [PersonCard] {
        if fails { throw PublicDataError.offline }
        return cards
    }

    func meta() async throws -> PublicMeta { throw PublicDataError.notFound }
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
    func agenda() async throws -> Agenda { throw PublicDataError.notFound }
    func money() async throws -> MoneyOverview { throw PublicDataError.notFound }
    func today() async throws -> TodayDigest { throw PublicDataError.notFound }
}

struct RaceFeed: LiveResultsService {
    var list: [Race] = []
    var fails = false

    func races() async throws -> [Race] {
        if fails { throw LiveResultsError.unavailable }
        return list
    }

    func follow(raceID: String, pushToken: String, environment: PushEnvironment) async throws {}

    func unfollow(pushToken: String) async throws {}
}

enum MemoryFixture {
    static func decode<Value: Decodable>(_ type: Value.Type, _ json: String) throws -> Value {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    static func pick(
        _ number: String, _ name: String, _ party: String, share: Double, elected: Bool = false
    ) -> String {
        """
        {"number":"\(number)","ballotName":"\(name)","party":"\(party)","votes":\(Int(share * 1_000)),\
        "share":\(share),"elected":\(elected),"advanced":false}
        """
    }

    static func race(
        _ id: String, year: Int, office: String, rounds: [(date: String, leaders: [String])]
    ) -> String {
        let list = rounds.enumerated().map { index, round in
            """
            {"round":\(index + 1),"date":"\(round.date)","turnout":79.4,\
            "leaders":[\(round.leaders.joined(separator: ","))]}
            """
        }
        return """
            {"id":"\(id)","year":\(year),"office":"\(office)","scope":"BR","scopeName":"Brasil",\
            "seats":1,"rounds":[\(list.joined(separator: ","))]}
            """
    }

    static func history() throws -> ElectionHistory {
        let races = [
            race(
                "2018-president", year: 2_018, office: "president",
                rounds: [
                    (
                        "2018-10-28",
                        [
                            pick("17", "BOLSONARO", "PSL", share: 55.13),
                            pick("13", "HADDAD", "PT", share: 44.87),
                        ]
                    )
                ]),
            race(
                "2022-president", year: 2_022, office: "president",
                rounds: [
                    (
                        "2022-10-02",
                        [
                            pick("13", "LULA", "PT", share: 48.43),
                            pick("22", "BOLSONARO", "PL", share: 43.2),
                        ]
                    ),
                    (
                        "2022-10-30",
                        [
                            pick("22", "BOLSONARO", "PL", share: 49.1),
                            pick("13", "LULA", "PT", share: 50.9, elected: true),
                        ]
                    ),
                ]),
            race(
                "2014-governor-sp", year: 2_014, office: "governor",
                rounds: [
                    ("2014-10-05", [pick("45", "ALCKMIN", "PSDB", share: 57.31, elected: true)])
                ]),
        ]
        return try decode(
            ElectionHistory.self,
            """
            {"years":[2022,2018,2014],"races":[\(races.joined(separator: ","))],"gaps":[],"method":[],\
            "sources":[]}
            """)
    }

    static func period(_ id: String, start: String, end: String?, presidents: [String]) -> String {
        let list = presidents.map {
            "{\"name\":\"\($0)\",\"start\":\"\(start)\",\"end\":null,\"how\":\"\",\"sources\":[]}"
        }
        let finish = end.map { "\"\($0)\"" } ?? "null"
        return """
            {"id":"\(id)","name":"\(id)","era":"","start":"\(start)","end":\(finish),"summary":"",\
            "presidents":[\(list.joined(separator: ","))],"milestones":[],"advances":[],\
            "critiques":[],"divergences":[],"indicators":[],"sources":[]}
            """
    }

    static func timeline() throws -> PoliticalTimeline {
        let periods = [
            period(
                "first-republic", start: "1889-11-15", end: "1930-10-24",
                presidents: ["Deodoro", "Floriano"]),
            period("vargas-era", start: "1930-11-03", end: "1945-10-29", presidents: ["Vargas"]),
            period(
                "new-republic", start: "1985-03-15", end: nil,
                presidents: ["Sarney", "Collor", "Lula"]),
        ]
        return try decode(
            PoliticalTimeline.self,
            "{\"version\":\"1\",\"method\":[],\"periods\":[\(periods.joined(separator: ","))]}")
    }

    static func study() throws -> StudyCatalog {
        try decode(
            StudyCatalog.self,
            """
            {"version":"1","method":[],"guides":[{"id":"how-voting-works","kind":"guide",\
            "title":"How voting works","summary":"","cards":[],"quiz":[\
            {"question":"First","options":["a","b"],"answer":1,"explanation":"","sources":[]},\
            {"question":"Second","options":["a","b"],"answer":0,"explanation":"","sources":[]}],\
            "terms":[{"term":"Quociente eleitoral","definition":"Divisão dos votos válidos","sources":[]},\
            {"term":"Coligação","definition":"União de partidos","sources":[]}],"sources":[]}]}
            """)
    }

    static func card(_ slug: String, _ name: String, status: PersonStatus) -> PersonCard {
        PersonCard(
            slug: slug, name: name, office: .senator, uf: "SP", party: "PT", photo: nil,
            status: status)
    }

    static func service() throws -> MemoryService {
        MemoryService(
            history: try history(), timeline: try timeline(), study: try study(),
            cards: [
                card("zelia", "Zélia Prado", status: .electedAwaiting),
                card("bruno", "Bruno Lima", status: .inOffice),
                card("alvaro", "Álvaro Dias", status: .electedAwaiting),
                card("carla", "Carla Reis", status: .onLeave),
            ])
    }

    static func race(_ id: String, office: Race.Office, counted percent: Double) -> Race {
        Race(
            id: id, office: office, uf: office == .president ? "BR" : "SP", round: 2,
            sections: Race.Sections(total: 1_000, counted: Int(percent * 10), percent: percent),
            electorate: 1_000, turnout: 800,
            votes: Race.Votes(valid: 700, blank: 50, null: 50, total: 800),
            candidates: [], final: false, sourceGeneratedAt: "2026-10-25T20:00:00Z")
    }

    static func day(
        _ year: Int, _ month: Int, _ day: Int, hour: Int = 12, minute: Int = 0,
        calendar: Calendar = FiscalCalendar.current
    ) throws -> Date {
        try #require(
            calendar.date(
                from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
            ))
    }
}
