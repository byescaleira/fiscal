import Foundation

public enum FiscalError: Error, LocalizedError, Equatable, Sendable {
    case onFetch, onSave, onRemove
    case invalidInput(String)
    case missingRecord
    case persistence(String)

    public var errorDescription: String? {
        switch self {
        case .onFetch: String(appLocalized: "Couldn't load the data. Try again.")
        case .onSave: String(appLocalized: "Couldn't save. Check the fields and try again.")
        case .onRemove: String(appLocalized: "Couldn't delete. Check the linked records.")
        case .invalidInput(let message), .persistence(let message): message
        case .missingRecord: String(appLocalized: "This record no longer exists. Refresh the list.")
        }
    }
}
