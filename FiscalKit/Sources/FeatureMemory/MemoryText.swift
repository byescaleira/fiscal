import FeatureCore
import FiscalDomain
import Foundation

enum MemoryText {
    private static let particles: Set<String> = ["da", "das", "de", "do", "dos", "e", "di"]

    static func name(_ raw: String) -> String {
        let words = raw.lowercased(with: .app).split(separator: " ")
        return words.enumerated().map { index, word in
            let text = String(word)
            if index > 0, particles.contains(text) { return text }
            return text.prefix(1).uppercased(with: .app) + text.dropFirst()
        }
        .joined(separator: " ")
    }

    static func slug(_ raw: String) -> String {
        let folded = raw.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .app)
        let parts = folded.lowercased().split { !$0.isLetter && !$0.isNumber }
        return parts.joined(separator: "-")
    }

    static func percent(_ share: Double) -> String {
        RaceText.percent(share)
    }

    static func shortPercent(_ share: Double) -> String {
        RaceText.shortPercent(share)
    }

    static func votes(_ value: Int) -> String {
        String(appLocalized: "\(RaceText.votes(value)) votes")
    }

    static func compactVotes(_ value: Int) -> String {
        RaceText.compactVotes(value)
    }

    static func day(_ day: CalendarDay?) -> String {
        day.map(SourceFootnote.day) ?? PublicFormat.missing
    }

    static func round(_ number: Int, total: Int) -> String {
        guard total > 1 else { return String(appLocalized: "Single round") }
        return String(appLocalized: "Round \(number)")
    }

    static func office(_ office: Office, seats: Int = 1) -> String {
        switch office {
        case .president: String(appLocalized: "President")
        case .governor: String(appLocalized: "Governor")
        case .senator:
            seats > 1 ? String(appLocalized: "Senate · 2 seats") : String(appLocalized: "Senate")
        default: office.title
        }
    }

    static func years(start: CalendarDay?, end: CalendarDay?) -> String {
        let from = start.map { String($0.year) } ?? PublicFormat.missing
        guard let end else { return String(appLocalized: "\(from) to today") }
        return "\(from)–\(String(end.year))"
    }

    static func sources(_ refs: [HistoryRef]) -> String? {
        var names: [String] = []
        for ref in refs where !names.contains(ref.name) { names.append(ref.name) }
        guard !names.isEmpty else { return nil }
        return String(appLocalized: "Source: \(names.joined(separator: "; "))")
    }
}
