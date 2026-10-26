import FeatureCore
import FiscalDomain
import Foundation

extension ProfileModel {
    public struct InfoLine: Identifiable, Equatable {
        public let id: String
        public let title: String
        public let value: String
    }

    public struct CoverageLine: Identifiable, Equatable {
        public let kind: String
        public let title: String
        public let status: Profile.Coverage.Status
        public let detail: String

        public var id: String { kind }
    }

    public var assetDeclarations: [Profile.AssetDeclaration] {
        (profile?.assets ?? []).sorted { $0.year > $1.year }
    }

    public var campaigns: [Profile.Campaign] {
        (profile?.campaigns ?? []).sorted { $0.year > $1.year }
    }

    public var timeline: [Profile.Career] {
        (profile?.timeline ?? []).sorted { $0.year > $1.year }
    }

    public var committees: [Profile.Committee] {
        (profile?.committees ?? []).sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    public var assetsNote: String {
        String(appLocalized: "As declared to the electoral court when running for office.")
    }

    public func money(_ cents: Int?) -> String { PublicFormat.money(cents: cents) }

    public func campaignDetail(_ campaign: Profile.Campaign) -> String {
        [Office.title(of: campaign.office, for: profile?.gender), campaign.result].compactMap(
            \.self
        )
        .joined(separator: " · ")
    }

    public func careerOffice(_ career: Profile.Career) -> String {
        Office.title(of: career.office, for: profile?.gender)
    }

    public func careerDetail(_ career: Profile.Career) -> String {
        [career.place, career.party, career.result].compactMap(\.self).joined(separator: " · ")
    }

    public func careerVotes(_ career: Profile.Career) -> String? {
        career.votes.map {
            String(appLocalized: "Votes received: \(PublicFormat.number($0))")
        }
    }

    public func committeeDetail(_ committee: Profile.Committee) -> String {
        let since = committee.start.map {
            String(appLocalized: "since \(SourceFootnote.day($0))")
        }
        return [committee.role, since].compactMap(\.self).joined(separator: " · ")
    }

    public var coverageLines: [CoverageLine] {
        (profile?.coverage ?? []).map { item in
            CoverageLine(
                kind: item.kind, title: Self.coverageTitle(item.kind), status: item.status,
                detail: coverageDetail(item))
        }
    }

    public var aboutLines: [InfoLine] {
        guard let profile else { return [] }
        var lines: [InfoLine] = []
        func add(_ id: String, _ title: String, _ value: String?) {
            guard let value, !value.isEmpty else { return }
            lines.append(InfoLine(id: id, title: title, value: value))
        }
        add("civil", String(appLocalized: "Civil name"), civilNameValue)
        add("birth", String(appLocalized: "Born"), profile.birthDate.map(SourceFootnote.day))
        add("birthPlace", String(appLocalized: "Birthplace"), profile.birthPlace)
        add("education", String(appLocalized: "Education"), profile.education)
        add(
            "salary", String(appLocalized: "Monthly salary"),
            profile.salary.map { PublicFormat.money(cents: $0.monthlyCents) })
        add("law", String(appLocalized: "Set by"), profile.salary?.law)
        add("email", String(appLocalized: "Email"), profile.contact?.email)
        add("phone", String(appLocalized: "Phone"), profile.contact?.phone)
        add("office", String(appLocalized: "Office"), profile.contact?.office)
        return lines
    }

    private var civilNameValue: String? {
        guard let profile, let civil = profile.civilName, civil != profile.name else { return nil }
        return civil
    }

    private func coverageDetail(_ item: Profile.Coverage) -> String {
        switch item.status {
        case .available:
            let source = item.source.flatMap { id in sources.first { $0.id == id }?.name }
            return source.map { String(appLocalized: "Published by \($0)") }
                ?? String(appLocalized: "Published")
        case .notPublished: return String(appLocalized: "The house doesn't publish this")
        case .notLoaded: return String(appLocalized: "Not loaded yet")
        }
    }

    static func coverageTitle(_ kind: String) -> String {
        switch kind {
        case "attendance": String(appLocalized: "Attendance")
        case "votes": String(appLocalized: "Votes")
        case "proposals": String(appLocalized: "Proposals")
        case "speeches": String(appLocalized: "Speeches")
        case "expenses": String(appLocalized: "Expenses")
        case "assets": String(appLocalized: "Declared assets")
        default: kind
        }
    }
}
