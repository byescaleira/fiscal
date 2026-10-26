import Foundation

public enum PortraitShelf {
    public static func slug(_ name: String) -> String {
        name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .joined(separator: "-")
    }

    public static func url(for slug: String) -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: HomePlace.appGroup)?
            .appending(path: "portraits", directoryHint: .isDirectory)
            .appending(path: "\(slug).png")
    }
}
