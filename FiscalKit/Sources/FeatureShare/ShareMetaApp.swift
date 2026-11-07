import Foundation

public enum ShareMetaApp {
    public static let infoKey = "FiscalMetaAppID"

    public static func id(info: [String: Any] = Bundle.main.infoDictionary ?? [:]) -> String? {
        guard let value = (info[infoKey] as? String)?.trimmingCharacters(in: .whitespaces),
            !value.isEmpty
        else { return nil }
        return value
    }
}
