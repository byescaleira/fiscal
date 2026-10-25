import FeatureCore
import FiscalDomain

struct ReleaseNote: Identifiable, Equatable {
    let symbol: String
    let color: RetroColor
    let title: String
    let detail: String

    var id: String { symbol }
}

extension ReleaseNote {
    static var firstVersion: [ReleaseNote] {
        [
            ReleaseNote(
                symbol: "icloud", color: .teal, title: String(appLocalized: "Your iCloud"),
                detail: String(
                    appLocalized: "Everything syncs through your own iCloud account, nowhere else."
                )),
            ReleaseNote(
                symbol: "book", color: .avocado, title: String(appLocalized: "Guides"),
                detail: String(appLocalized: "Short guides for every part of the app.")),
            ReleaseNote(
                symbol: "globe", color: .denim, title: String(appLocalized: "Ten Languages"),
                detail: String(appLocalized: "Change the app's language right in Settings.")),
        ]
    }
}
