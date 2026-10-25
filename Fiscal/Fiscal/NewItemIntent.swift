import AppIntents
import Foundation

struct NewItemIntent: AppIntent {
    static let title: LocalizedStringResource = "New Item"
    static let description = IntentDescription("Opens Fiscal on a new item.")
    static let openAppWhenRun = true
    static let url = URL(string: "fiscal://items/new")
    @MainActor static var open: ((URL) -> Void)?

    @MainActor
    func perform() async throws -> some IntentResult {
        if let url = Self.url { Self.open?(url) }
        return .result()
    }
}
