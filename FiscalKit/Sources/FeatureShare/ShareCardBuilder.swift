import FiscalDomain
import Foundation

public struct ShareCardBuilder: Sendable {
    public static let host = "fiscal.byescaleira.com"

    let calendar: Calendar

    public init(calendar: Calendar = FiscalCalendar.current) {
        self.calendar = calendar
    }

    public func person(_ profile: Profile) -> ShareCardContent {
        let source = primarySource(profile.sources, for: profile.office)
        return ShareCardContent(
            eyebrow: eyebrow(String(appLocalized: "Profile"), profile.office.title, uf(profile.uf)),
            headline: nil, faces: [face(profile)], body: .person(metrics(profile)),
            source: sourceLine(source),
            stamp: stamp(source, "PER", profile.slug, source?.updatedAt),
            link: link("person", profile.slug))
    }

    public func vote(_ detail: VoteDetail) -> ShareCardContent {
        let vote = detail.vote
        let source = detail.sources.first { $0.id == vote.house.rawValue } ?? detail.sources.first
        return ShareCardContent(
            eyebrow: eyebrow(
                String(appLocalized: "Floor vote"), vote.house.title, dayMonth(vote.date)),
            headline: vote.plainSummary ?? vote.summary, faces: [], body: .vote(tally(detail)),
            source: sourceLine(source),
            stamp: stamp(source, "VOT", vote.id, vote.date.date(in: calendar)),
            link: link("vote", vote.id))
    }

    public func expenses(_ profile: Profile, list: ExpenseList, year: Int) -> ShareCardContent {
        let source = primarySource(profile.sources, for: profile.office)
        return ShareCardContent(
            eyebrow: eyebrow(String(appLocalized: "Office allowance"), String(year)),
            headline: nil, faces: [face(profile)],
            body: .expenses(spending(list, year: year)), source: sourceLine(source),
            stamp: stamp(source, "GAS", "\(profile.slug)-\(year)", source?.updatedAt),
            link: link("expenses", "\(profile.slug)-\(year)"))
    }

    func face(_ profile: Profile) -> ShareFace {
        ShareFace(
            slug: profile.slug, name: profile.name, party: profile.party,
            detail: [uf(profile.uf), profile.office.title].joined(separator: " · "))
    }

    func metrics(_ profile: Profile) -> [ShareMetric] {
        let numbers = profile.numbers
        guard isLegislator(profile.office) else {
            return [
                ShareMetric(
                    label: String(appLocalized: "Votes in the last election"),
                    value: PublicFormat.number(numbers.lastElectionVotes)),
                ShareMetric(
                    label: String(appLocalized: "Declared assets"),
                    value: PublicFormat.compactMoney(cents: numbers.assetsCents)),
                ShareMetric(
                    label: String(appLocalized: "Campaign revenue"),
                    value: PublicFormat.compactMoney(cents: numbers.campaignRevenueCents)),
                ShareMetric(
                    label: String(appLocalized: "Term ends"),
                    value: profile.mandate?.end.map(fullDate) ?? PublicFormat.missing),
            ]
        }
        return [
            ShareMetric(
                label: String(appLocalized: "Attendance"),
                value: PublicFormat.percent(numbers.attendance?.fraction)),
            ShareMetric(
                label: String(appLocalized: "Roll-call votes"),
                value: PublicFormat.number(numbers.votes)),
            ShareMetric(
                label: String(appLocalized: "Bills filed"),
                value: PublicFormat.number(numbers.proposals)),
            ShareMetric(
                label: String(appLocalized: "Office allowance used"),
                value: PublicFormat.compactMoney(cents: numbers.quotaCents)),
        ]
    }

    func tally(_ detail: VoteDetail) -> ShareTally {
        let vote = detail.vote
        let total = Double(vote.tally.total ?? 0)
        let share: (Int?) -> Double = { value in
            guard let value, total > 0 else { return 0 }
            return Double(value) / total
        }
        let official = vote.plainSummary == nil ? nil : vote.summary
        return ShareTally(
            proposition: [vote.proposition, vote.kind].compactMap(\.self).joined(separator: " · "),
            official: official, yes: PublicFormat.number(vote.yes),
            no: PublicFormat.number(vote.no), others: PublicFormat.number(vote.others),
            yesShare: share(vote.yes), noShare: share(vote.no), othersShare: share(vote.others),
            result: result(vote), approved: vote.approved,
            quorum: detail.quorum.map {
                String(appLocalized: "Quorum: \(PublicFormat.number($0))")
            })
    }

    func spending(_ list: ExpenseList, year: Int) -> ShareSpending {
        let sorted = list.byCategory.sorted { $0.cents > $1.cents }
        let shown = sorted.count > 4 ? Array(sorted.prefix(3)) : sorted
        let rest = sorted.dropFirst(shown.count).reduce(0) { $0 + $1.cents }
        let total = Double(max(list.totalCents, 1))
        var categories = shown.map {
            ShareSpending.Category(
                name: $0.category, value: PublicFormat.money(cents: $0.cents),
                share: Double($0.cents) / total)
        }
        if rest > 0 {
            categories.append(
                ShareSpending.Category(
                    name: String(appLocalized: "Other categories"),
                    value: PublicFormat.money(cents: rest), share: Double(rest) / total))
        }
        return ShareSpending(
            total: PublicFormat.money(cents: list.totalCents),
            caption: String(appLocalized: "Office allowance spending in \(String(year))"),
            receipts: String(appLocalized: "Receipts: \(PublicFormat.number(list.items.count))"),
            categories: categories)
    }

    func result(_ vote: VoteSummary) -> String? {
        switch vote.approved {
        case .some(true): String(appLocalized: "Approved")
        case .some(false): String(appLocalized: "Rejected")
        case .none: vote.result
        }
    }

    func isLegislator(_ office: Office) -> Bool {
        [.senator, .federalDeputy, .stateDeputy].contains(office)
    }

    func primarySource(_ sources: [Source], for office: Office) -> Source? {
        let preferred =
            switch office {
            case .senator: "senado"
            case .federalDeputy: "camara"
            case .president, .vicePresident, .governor, .viceGovernor, .stateDeputy:
                Source.electionID
            case .mayor, .viceMayor, .cityCouncilor: Source.municipalElectionID
            }
        return sources.first { $0.id == preferred } ?? sources.first
    }

    func sourceLine(_ source: Source?) -> String {
        sourceLine(name: source?.name ?? PublicFormat.missing, updatedAt: source?.updatedAt)
    }

    func sourceLine(name: String, updatedAt: Date?) -> String {
        guard let updatedAt else { return String(appLocalized: "Source: \(name)") }
        return String(appLocalized: "Source: \(name) · updated \(moment(updatedAt))")
    }

    func eyebrow(_ parts: String...) -> String {
        parts.filter { !$0.isEmpty }.joined(separator: " · ").uppercased()
    }

    func uf(_ value: String) -> String {
        value == "br" ? RaceText.scope(value) : value.uppercased()
    }

    func stamp(_ source: Source?, _ code: String, _ reference: String, _ date: Date?) -> String {
        stamp(origin: source?.id ?? "fiscal", code, reference, date)
    }

    func stamp(origin: String, _ code: String, _ reference: String, _ date: Date?) -> String {
        let day =
            date.map { CalendarDay($0, calendar: calendar).description } ?? PublicFormat.missing
        return [origin, code, reference, day, Self.host]
            .map { $0.replacingOccurrences(of: " ", with: "") }
            .joined(separator: "·").uppercased()
    }

    func link(_ key: String, _ value: String) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = Self.host
        components.path = "/"
        components.queryItems = [URLQueryItem(name: key, value: value)]
        return components.url ?? URL(fileURLWithPath: "/")
    }

    func moment(_ date: Date) -> String {
        let parts = calendar.dateComponents([.day, .month, .hour, .minute], from: date)
        return String(
            format: "%02d/%02d, %02d:%02d", parts.day ?? 0, parts.month ?? 0, parts.hour ?? 0,
            parts.minute ?? 0)
    }

    func dayMonth(_ day: CalendarDay) -> String {
        String(format: "%02d/%02d", day.day, day.month)
    }

    func fullDate(_ day: CalendarDay) -> String {
        String(format: "%02d/%02d/%04d", day.day, day.month, day.year)
    }
}
