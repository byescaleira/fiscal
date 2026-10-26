import FiscalDesignSystem
import FiscalDomain
import SwiftUI

enum PeriodPalette {
    private static let slots: [String: Int] = [
        "República Velha": 3, "Era Vargas": 1, "República de 1946": 0, "Ditadura militar": 2,
        "Nova República": 5,
    ]

    static func color(for era: String) -> Color {
        ChartPalette.color(at: slots[era] ?? 4)
    }
}

enum StudySymbols {
    private static let symbols: [String: String] = [
        "tres-poderes": "building.columns", "como-nasce-uma-lei": "doc.text",
        "sistema-proporcional": "chart.pie", "cargos": "person.3", "impeachment": "hammer",
        "glossario": "character.book.closed",
    ]

    static func symbol(for id: String) -> String {
        symbols[id] ?? "book"
    }

    static func count(_ guide: StudyGuide) -> String {
        switch guide.kind {
        case .glossary: String(appLocalized: "\(guide.terms.count) terms")
        case .guide:
            guide.quiz.isEmpty
                ? String(appLocalized: "\(guide.cards.count) cards")
                : String(appLocalized: "\(guide.cards.count) cards · \(guide.quiz.count) questions")
        }
    }
}

enum MilestoneStyle {
    static func symbol(_ kind: PeriodMilestone.Kind) -> String {
        switch kind {
        case .constitution: "text.book.closed"
        case .law: "doc.text"
        case .economy: "chart.line.uptrend.xyaxis"
        case .election: "checkmark.rectangle.stack"
        case .rupture: "bolt"
        case .impeachment: "person.crop.circle.badge.xmark"
        case .event: "calendar"
        }
    }

    static func label(_ kind: PeriodMilestone.Kind) -> String {
        switch kind {
        case .constitution: String(appLocalized: "Constitution")
        case .law: String(appLocalized: "Law")
        case .economy: String(appLocalized: "Economy")
        case .election: String(appLocalized: "Election")
        case .rupture: String(appLocalized: "Break in order")
        case .impeachment: String(appLocalized: "Impeachment")
        case .event: String(appLocalized: "Event")
        }
    }
}
