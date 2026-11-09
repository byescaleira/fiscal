import Foundation

public enum PortraitShelf {
    public static func slug(_ name: String) -> String {
        name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .joined(separator: "-")
    }

    public static func url(for slug: String) -> URL? {
        guard isSafe(slug) else { return nil }
        return AppGroup.containerURL?
            .appending(path: "portraits", directoryHint: .isDirectory)
            .appending(path: "\(slug).png")
    }

    static func isSafe(_ slug: String) -> Bool {
        !slug.isEmpty
            && slug.unicodeScalars.allSatisfy {
                ("a"..."z").contains($0) || ("0"..."9").contains($0) || $0 == "-"
            }
    }
}
