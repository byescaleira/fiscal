import FiscalDomain
import Foundation

enum OfflinePackPlan {
    static let baseFiles = [
        PublicDataPath.meta, PublicDataPath.people, PublicDataPath.places, PublicDataPath.today,
        PublicDataPath.agenda, PublicDataPath.highlights, PublicDataPath.recentVotes, "races.json",
    ]
    static let peopleLimit = 40
    static let representativesLimit = 12
    static let byteBudget = OfflinePackSummary.limitBytes
    static let representativeOffices: [Office] = [
        .president, .vicePresident, .governor, .viceGovernor, .senator, .mayor, .viceMayor,
    ]

    static func regionFiles(placeCode: String?) -> [String] {
        guard let code = placeCode?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            let uf = HomePlace.uf(fromPlaceCode: code)
        else { return [] }
        var files = [PublicDataPath.representatives(uf: uf)]
        if code != uf { files.append(PublicDataPath.cityRepresentatives(code: code)) }
        return files
    }

    static func representatives(in places: [PlaceRepresentatives]) -> [String] {
        let people = places.flatMap(\.groups)
            .filter { representativeOffices.contains($0.office) }
            .sorted {
                representativeOffices.firstIndex(of: $0.office) ?? .max
                    < representativeOffices.firstIndex(of: $1.office) ?? .max
            }
            .flatMap(\.people)
            .map(\.slug)
        return Array(unique(people).prefix(representativesLimit))
    }

    static func people(for request: OfflinePackRequest, representatives: [String]) -> [String] {
        let ordered = (request.followed + request.supported).sorted() + representatives
        return Array(unique(ordered.filter(isSlug)).prefix(peopleLimit))
    }

    static func isSlug(_ value: String) -> Bool {
        !value.isEmpty && !value.contains("..")
            && value.allSatisfy { $0.isASCII && ($0.isLowercase || $0.isNumber || $0 == "-") }
    }

    private static func unique(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        return values.filter { seen.insert($0).inserted }
    }
}
