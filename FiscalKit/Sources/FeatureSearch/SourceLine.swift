import FiscalDomain
import Foundation

enum SourceLine {
    static func text(_ sources: [Source], updatedAt: Date? = nil) -> String? {
        var seen = Set<String>()
        let names = sources.filter { seen.insert($0.id).inserted }.map(\.name)
        guard !names.isEmpty else { return nil }
        let list = names.formatted(.list(type: .and).locale(.app))
        let latest = updatedAt ?? sources.compactMap(\.updatedAt).max()
        guard let latest else { return String(appLocalized: "Source: \(list)") }
        let date = PublicFormat.updated(latest)
        return String(appLocalized: "Source: \(list) · updated \(date)")
    }
}
