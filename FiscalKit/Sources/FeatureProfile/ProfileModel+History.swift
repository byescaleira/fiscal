import FeatureCore
import FiscalDomain
import Foundation

extension ProfileModel {
    public struct InfoLine: Identifiable, Equatable {
        public let id: String
        public let title: String
        public let value: String
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
        if !profile.office.isLegislative { lines += salaryLines }
        add("email", String(appLocalized: "Email"), profile.contact?.email)
        add("phone", String(appLocalized: "Phone"), profile.contact?.phone)
        add("office", String(appLocalized: "Office"), profile.contact?.office)
        return lines
    }

    public var salaryLines: [InfoLine] {
        guard let salary = profile?.salary else { return [] }
        let law = salary.law.map {
            InfoLine(id: "law", title: String(appLocalized: "Set by"), value: $0)
        }
        return [
            InfoLine(
                id: "salary", title: String(appLocalized: "Monthly salary"),
                value: PublicFormat.money(cents: salary.monthlyCents)),
            law,
        ].compactMap(\.self)
    }

    public var checkItems: [FactCheck] {
        (checks?.items ?? []).sorted { $0.date > $1.date }
    }

    private var civilNameValue: String? {
        guard let profile, let civil = profile.civilName, civil != profile.name else { return nil }
        return civil
    }

    static func coverageTitle(_ kind: String) -> String {
        switch kind {
        case "attendance": String(appLocalized: "Attendance")
        case "votes": String(appLocalized: "Votes")
        case "proposals": String(appLocalized: "Proposals")
        case "speeches": String(appLocalized: "Speeches")
        case "expenses": String(appLocalized: "Expenses")
        case "assets": String(appLocalized: "Declared assets")
        case "campaigns": String(appLocalized: "Campaigns")
        case "salary": String(appLocalized: "Salary")
        default: kind
        }
    }
}
