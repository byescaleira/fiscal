import FiscalDesignSystem
import FiscalDomain
import SwiftUI
import WidgetKit

enum FollowingLine {
    static let widgetLimit = 4

    static func entries(_ snapshot: FollowingSnapshot) -> [FollowingSnapshot.Entry] {
        Array(snapshot.entries.prefix(widgetLimit))
    }

    static func place(_ person: PersonCard) -> String {
        let uf = person.uf.lowercased() == "br" ? nil : person.uf.uppercased(with: .app)
        return [person.party, uf].compactMap(\.self).filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    static func update(
        _ update: FollowingUpdate?, calendar: Calendar = GregorianCalendar.current
    ) -> String {
        guard let update else { return String(appLocalized: "No recent updates") }
        switch update.kind {
        case .vote(let vote):
            guard !vote.vote.isEmpty else { return vote.heading }
            return String(appLocalized: "Voted \(vote.vote) · \(vote.heading)")
        case .expenses(_, _, let cents):
            let style = Date.VerbatimFormatStyle(
                format: "\(month: .wide)", locale: .app, timeZone: calendar.timeZone,
                calendar: calendar)
            let month = update.day.date(in: calendar).formatted(style)
            return String(
                appLocalized: "Expenses for \(month): \(PublicFormat.money(cents: cents))")
        case .check(let check):
            let detail = check.verdict.map { "\($0) · \(check.title)" } ?? check.title
            return String(appLocalized: "Fact check: \(detail)")
        }
    }

    static func day(_ update: FollowingUpdate?) -> String? {
        guard let update else { return nil }
        switch update.kind {
        case .vote, .check: return String(format: "%02d/%02d", update.day.day, update.day.month)
        case .expenses: return nil
        }
    }

    static func accessibility(_ entry: FollowingSnapshot.Entry) -> String {
        [entry.person.name, place(entry.person), update(entry.latest), day(entry.latest)]
            .compactMap(\.self).filter { !$0.isEmpty }.joined(separator: ", ")
    }

    static func accessibility(_ snapshot: FollowingSnapshot) -> String? {
        guard let first = snapshot.entries.first else { return nil }
        let others = snapshot.entries.count - 1
        guard others > 0 else { return accessibility(first) }
        return "\(accessibility(first)), \(String(appLocalized: "and \(others) more"))"
    }
}

struct FollowingSmall: View {
    let snapshot: FollowingSnapshot

    var body: some View {
        let entries = FollowingLine.entries(snapshot)
        VStack(alignment: .leading, spacing: .spaceS) {
            HStack(alignment: .top) {
                Text("Following")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(WidgetStyle.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "person.2")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(WidgetStyle.secondary)
                    .accessibilityHidden(true)
            }
            HStack(spacing: -.spaceS) {
                ForEach(entries) { entry in
                    PersonPortrait(
                        slug: entry.person.slug, name: entry.person.name,
                        party: entry.person.party, size: .badgeM
                    )
                    .overlay { Circle().stroke(WidgetStyle.board, lineWidth: .spaceHairline) }
                    .widgetAccentable()
                }
            }
            .accessibilityHidden(true)
            Spacer(minLength: 0)
            if let first = entries.first {
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: first.person.name)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(WidgetStyle.primary)
                        .lineLimit(1)
                    Text(verbatim: FollowingLine.update(first.latest))
                        .font(.caption2)
                        .foregroundStyle(WidgetStyle.secondary)
                        .lineLimit(2)
                }
                .minimumScaleFactor(.widgetTextShrink)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: FollowingLine.accessibility(snapshot) ?? ""))
            }
        }
        .privacySensitive()
    }
}

struct FollowingMedium: View {
    let snapshot: FollowingSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceHairline) {
            ForEach(FollowingLine.entries(snapshot)) { entry in
                if let url = IntegrationLink.person(entry.person.slug) {
                    Link(destination: url) { FollowingRow(entry: entry) }
                } else {
                    FollowingRow(entry: entry)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct FollowingRow: View {
    let entry: FollowingSnapshot.Entry

    var body: some View {
        HStack(spacing: .spaceS) {
            PersonPortrait(
                slug: entry.person.slug, name: entry.person.name, party: entry.person.party,
                size: .badgeS
            )
            .widgetAccentable()
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: .spaceXS) {
                    Text(verbatim: entry.person.name)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(WidgetStyle.primary)
                    Text(verbatim: FollowingLine.place(entry.person))
                        .font(.caption2)
                        .foregroundStyle(WidgetStyle.secondary)
                    Spacer(minLength: 0)
                    if let day = FollowingLine.day(entry.latest) {
                        Text(verbatim: day)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(WidgetStyle.secondary)
                    }
                }
                Text(verbatim: FollowingLine.update(entry.latest))
                    .font(.caption2)
                    .foregroundStyle(WidgetStyle.secondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(.widgetTextShrink)
        }
        .privacySensitive()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: FollowingLine.accessibility(entry)))
    }
}
