import CoreGraphics
import FiscalDomain
import Foundation
import ImageIO
import UniformTypeIdentifiers

extension PortraitStore {
    public static let shelfSide: CGFloat = 120
    public static let shelfLifetime: TimeInterval = 7 * 86_400

    public static func pruneShelf(now: Date = .now, fileManager: FileManager = .default) {
        guard let folder = PortraitShelf.url(for: "x")?.deletingLastPathComponent(),
            let files = try? fileManager.contentsOfDirectory(
                at: folder, includingPropertiesForKeys: [.contentModificationDateKey])
        else { return }
        for file in files {
            let date = try? file.resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate
            if let date, now.timeIntervalSince(date) > shelfLifetime {
                try? fileManager.removeItem(at: file)
            }
        }
    }

    public func shelve(slug: String, party: String) {
        guard let url = PortraitShelf.url(for: slug),
            let animation = animation(slug: slug, party: party),
            let image = PortraitStill.render(animation, side: Self.shelfSide)
        else { return }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard
            let destination = CGImageDestinationCreateWithURL(
                url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { return }
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
    }
}
