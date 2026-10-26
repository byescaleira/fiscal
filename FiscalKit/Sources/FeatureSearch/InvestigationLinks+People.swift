import FeatureCore
import FiscalDomain
import Foundation

extension InvestigationLinks {
    func personLinks(_ card: PersonCard) -> [InvestigationLink] {
        var links: [InvestigationLink] = []
        let profile = evidence.profiles[card.slug]
        if pieces.contains(.person(card)) || pieces.people.count == 1 {
            if let link = guidance(card) { links.append(link) }
            if let profile, let link = peer(profile, metric: .presence) { links.append(link) }
        }
        if pieces.has(.spending, for: card.slug), let profile {
            if let link = peer(profile, metric: .quota) { links.append(link) }
        }
        if let profile {
            for theme in pieces.themes { links.append(themeWork(profile, theme: theme)) }
        }
        if pieces.has(.checks, for: card.slug), evidence.checked.contains(card.slug) {
            links.append(checks(card))
        }
        if pieces.has(.context, for: card.slug), let link = context(card) { links.append(link) }
        for piece in pieces {
            if case .highlight(let ref) = piece, ref.person?.slug == card.slug {
                links.append(highlight(ref, card: card))
            }
        }
        return links
    }

    func guidance(_ card: PersonCard) -> InvestigationLink? {
        let question = String(appLocalized: "Does \(card.name) vote like the party?")
        let id = InvestigationPiece.person(card).id
        guard let facts = evidence.facts?.facts(for: card.slug) else { return nil }
        guard let guidance = facts.guidance, guidance.total > 0 else {
            guard card.office == .senator else { return nil }
            return InvestigationLink(
                id: "guidance-\(card.slug)", question: question,
                sentence: String(
                    appLocalized:
                        "The Federal Senate doesn't publish party guidance, so this can't be checked for \(card.name)."
                ),
                source: String(appLocalized: "Source: Federal Senate"), pieces: [id],
                visual: .counts([]),
                uncertainty: String(
                    appLocalized: "Data not published: party guidance in the Senate."))
        }
        let sentence = String(
            appLocalized:
                "In \(PublicFormat.number(guidance.total)) roll-call votes with party guidance, \(card.name) voted like the party in \(PublicFormat.number(guidance.followed)), against it in \(PublicFormat.number(guidance.against)) and otherwise in \(PublicFormat.number(guidance.other))."
        )
        let period = guidance.first.map {
            String(
                appLocalized:
                    "Counts only roll-call votes with published guidance since \(PublicFormat.updatedDay($0))."
            )
        }
        return InvestigationLink(
            id: "guidance-\(card.slug)", question: question, sentence: sentence,
            source: String(appLocalized: "Source: Chamber of Deputies"), pieces: [id],
            visual: .guidance(guidance),
            keyNumber: InvestigationSummary.KeyNumber(
                value:
                    "\(PublicFormat.number(guidance.followed))/\(PublicFormat.number(guidance.total))",
                label: String(appLocalized: "votes like the party, \(card.name)")),
            compared: String(
                appLocalized: "Each vote against the guidance of the person's own party"),
            uncertainty: period)
    }

    func peer(_ profile: Profile, metric: PeerClassification.Metric) -> InvestigationLink? {
        let card = profile.card
        let piece =
            metric == .quota
            ? InvestigationPiece.spending(card).id : InvestigationPiece.person(card).id
        let question =
            metric == .quota
            ? String(appLocalized: "How does \(card.name)'s spending compare with peers?")
            : String(appLocalized: "How does \(card.name)'s attendance compare with peers?")
        guard let classification = profile.classification,
            let entry = classification.entry(metric),
            let median = classification.medianText(metric)
        else {
            guard metric == .quota else { return nil }
            return InvestigationLink(
                id: "peer-\(metric.rawValue)-\(card.slug)", question: question,
                sentence: String(
                    appLocalized: "Comparison with peers isn't published for \(card.officeTitle)."),
                source: nil, pieces: [piece], visual: .counts([]),
                uncertainty: String(
                    appLocalized: "Data not published: comparison with peers for this office."),
                route: nil)
        }
        let value = metric.format(entry.value)
        let peers = entry.n.map { PublicFormat.number($0) } ?? PublicFormat.missing
        let sentence = String(
            appLocalized:
                "\(metric.title) of \(card.name) in \(String(classification.year)): \(value). \(median)."
        )
        let limit =
            metric == .quota
            ? String(appLocalized: "Spending below average doesn't mean spending well.")
            : String(appLocalized: "Attendance doesn't measure committee work.")
        return InvestigationLink(
            id: "peer-\(metric.rawValue)-\(card.slug)", question: question, sentence: sentence,
            source: profile.sources.first.map { String(appLocalized: "Source: \($0.name)") },
            pieces: [piece],
            visual: .peer(
                InvestigationLink.PeerStrip(
                    metric: metric, entry: entry, median: median, value: value)),
            keyNumber: InvestigationSummary.KeyNumber(
                value: value, label: "\(metric.title), \(card.name)"),
            compared: String(
                appLocalized:
                    "\(metric.title) against \(peers) peers in the same office and house in \(String(classification.year))"
            ),
            uncertainty: limit,
            route: metric == .quota
                ? .expenses(slug: card.slug, year: classification.year) : .person(slug: card.slug))
    }

    func themeWork(_ profile: Profile, theme: Theme) -> InvestigationLink {
        let card = profile.card
        let count = profile.themes.first { $0.key == theme }
        let proposals = count?.proposals ?? 0
        let speeches = count?.speeches ?? 0
        return InvestigationLink(
            id: "theme-\(theme.rawValue)-\(card.slug)",
            question: String(appLocalized: "What did \(card.name) do on \(theme.title)?"),
            sentence: String(
                appLocalized:
                    "\(card.name) filed \(PublicFormat.number(proposals)) proposals and gave \(PublicFormat.number(speeches)) speeches on \(theme.title) in the term."
            ),
            source: profile.sources.first.map { String(appLocalized: "Source: \($0.name)") },
            pieces: [InvestigationPiece.person(card).id, InvestigationPiece.theme(theme).id],
            visual: .counts([
                InvestigationLink.Count(
                    value: PublicFormat.number(proposals), label: String(appLocalized: "Proposals")),
                InvestigationLink.Count(
                    value: PublicFormat.number(speeches), label: String(appLocalized: "Speeches")),
            ]),
            keyNumber: InvestigationSummary.KeyNumber(
                value: PublicFormat.number(proposals),
                label: String(appLocalized: "proposals on \(theme.title)")),
            uncertainty: String(
                appLocalized:
                    "Estimated: each proposal's topic comes from keywords in its official summary and can miss."
            ),
            route: .person(slug: card.slug))
    }

    func checks(_ card: PersonCard) -> InvestigationLink {
        let items = evidence.checks[card.slug]?.items ?? []
        let lines = items.prefix(3).map { check in
            InvestigationLink.CheckLine(
                id: check.id, title: check.title, verdict: check.verdict,
                date: PublicFormat.updatedDay(check.date), url: check.url)
        }
        let sentence =
            items.isEmpty
            ? String(
                appLocalized:
                    "Projeto Comprova has no published fact check that names \(card.name).")
            : String(
                appLocalized:
                    "Projeto Comprova published \(PublicFormat.number(items.count)) fact checks that name \(card.name)."
            )
        return InvestigationLink(
            id: "checks-\(card.slug)",
            question: String(appLocalized: "Were there fact checks about \(card.name)?"),
            sentence: sentence,
            source: String(appLocalized: "Source: Projeto Comprova · CC BY-ND 4.0"),
            pieces: [InvestigationPiece.checks(card).id],
            visual: .checks(lines, total: items.count),
            keyNumber: items.isEmpty
                ? nil
                : InvestigationSummary.KeyNumber(
                    value: PublicFormat.number(items.count),
                    label: String(appLocalized: "fact checks naming \(card.name)")),
            uncertainty: String(
                appLocalized:
                    "A fact check that names someone isn't always about something that person said."
            ))
    }

    func context(_ card: PersonCard) -> InvestigationLink? {
        guard let context = evidence.contexts[card.slug],
            let item = context.indicators.first(where: { $0.id == "ipca" })
                ?? context.indicators.first
        else { return nil }
        let during = PublicFormat.percent(item.changeDuring)
        let before = PublicFormat.percent(item.changeBefore)
        return InvestigationLink(
            id: "context-\(card.slug)",
            question: String(
                appLocalized: "What changed before and during the term of \(card.name)?"),
            sentence: String(
                appLocalized:
                    "\(item.name) in \(item.area): \(during) in the \(item.months) months since \(card.name) took office, and \(before) in the \(item.months) months before."
            ),
            source: context.sources.first.map { String(appLocalized: "Source: \($0.name)") },
            pieces: [InvestigationPiece.context(card).id],
            visual: .change(
                before: item.changeBefore, during: item.changeDuring, name: item.name,
                months: item.months),
            keyNumber: item.changeDuring == nil
                ? nil
                : InvestigationSummary.KeyNumber(
                    value: during, label: String(appLocalized: "\(item.name) during the term")),
            compared: String(appLocalized: "The same number of months before and during the term"),
            uncertainty: String(
                appLocalized: "Prices don't depend on one person: this is context, not cause."))
    }

    func highlight(_ ref: HighlightRef, card: PersonCard) -> InvestigationLink {
        let relevance = Relevance(weight: ref.weight)
        return InvestigationLink(
            id: "highlight-\(ref.id)-\(card.slug)",
            question: String(appLocalized: "Where does \(card.name) appear in the highlights?"),
            sentence: String(
                appLocalized:
                    "\(card.name) appears in the highlight “\(ref.title)”, \(relevance.title)."),
            source: String(appLocalized: "Source: Fiscal highlights · repercussion + impact"),
            pieces: [InvestigationPiece.highlight(ref).id, InvestigationPiece.person(card).id],
            visual: .highlight(ref),
            uncertainty: ref.uncertainty
                ?? String(
                    appLocalized:
                        "Estimated: relevance is a weight from repercussion and impact, not an official number."
                ))
    }

    func pair(_ first: PersonCard, _ second: PersonCard) -> InvestigationLink? {
        guard let lhs = evidence.profiles[first.slug]?.classification,
            let rhs = evidence.profiles[second.slug]?.classification
        else { return nil }
        let rows = PeerClassification.Metric.allCases.compactMap {
            metric -> InvestigationLink.PairRow? in
            guard let left = lhs.entry(metric), let right = rhs.entry(metric) else { return nil }
            let top = max(left.value, right.value, 1)
            return InvestigationLink.PairRow(
                label: metric.title,
                values: [metric.format(left.value), metric.format(right.value)],
                shares: [left.value / top, right.value / top])
        }
        guard !rows.isEmpty else { return nil }
        let text = rows.map {
            "\($0.label): \(first.name) \($0.values[0]), \(second.name) \($0.values[1])"
        }
        .joined(separator: "; ")
        return InvestigationLink(
            id: "pair-\(first.slug)-\(second.slug)",
            question: String(appLocalized: "\(first.name) and \(second.name), side by side"),
            sentence: "\(text).", source: nil,
            pieces: [InvestigationPiece.person(first).id, InvestigationPiece.person(second).id],
            visual: .pair(faces: [first, second], rows: rows),
            compared: lhs.year == rhs.year && lhs.house == rhs.house
                ? String(appLocalized: "The same numbers, same year and same house")
                : nil,
            uncertainty: lhs.year != rhs.year || lhs.house != rhs.house
                ? String(
                    appLocalized:
                        "Different houses or years: each number compares with its own peers.")
                : nil,
            route: .compare(slugs: [first.slug, second.slug]))
    }
}

extension PublicFormat {
    static func updatedDay(_ day: CalendarDay) -> String {
        day.date().formatted(.dateTime.day().month(.abbreviated).year().locale(.app))
    }
}
