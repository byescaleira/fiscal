import FiscalDomain
import Foundation

struct Release: Identifiable, Equatable {
    let version: String
    let headline: String
    let notes: [ReleaseNote]

    var id: String { version }

    var title: String { String(appLocalized: "Version \(version)") }

    var heroNotes: [ReleaseNote] { Array(notes.prefix(5)) }

    static var all: [Release] {
        [
            Release(
                version: "1.0", headline: String(appLocalized: "The first version of Fiscal."),
                notes: ReleaseNote.firstVersion)
        ]
    }

    static func ordered(_ releases: [Release]) -> [Release] {
        releases.sorted { $0.version.compare($1.version, options: .numeric) == .orderedDescending }
    }

    static func featured(for version: String, in releases: [Release] = all) -> Release? {
        let ordered = ordered(releases)
        return ordered.first {
            $0.version.compare(version, options: .numeric) != .orderedDescending
        } ?? ordered.last
    }

    static func earlier(than version: String, in releases: [Release] = all) -> [Release] {
        let featured = featured(for: version, in: releases)
        return ordered(releases).filter {
            $0 != featured && $0.version.compare(version, options: .numeric) != .orderedDescending
        }
    }
}

extension SettingsModel {
    var featuredRelease: Release? { Release.featured(for: info.number) }

    var earlierReleases: [Release] { Release.earlier(than: info.number) }
}
