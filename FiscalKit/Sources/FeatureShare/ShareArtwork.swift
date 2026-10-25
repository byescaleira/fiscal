import FiscalDomain
import FiscalResource
import Foundation

public struct ShareArtwork: Hashable, Sendable {
    public let work: ArtWork
    public let palette: [String]

    public init(work: ArtWork, palette: [String]) {
        self.work = work
        self.palette = palette
    }

    public var credit: String {
        String(
            appLocalized:
                "Art: \(work.artist), \(work.title) (\(work.year)) · \(work.licenseLabel) · \(work.archive)"
        )
    }

    public var shade: String? {
        palette.max { HexColor.saturation($0) < HexColor.saturation($1) }
    }

    public var isBackdrop: Bool { work.isPublicDomain }
}

public struct ShareCard: Hashable, Sendable {
    public let content: ShareCardContent
    public let artwork: ShareArtwork?
    public let format: ShareFormat

    public init(content: ShareCardContent, artwork: ShareArtwork?, format: ShareFormat) {
        self.content = content
        self.artwork = artwork
        self.format = format
    }

    public var brand: String { "Fiscal" }

    public var poster: SharePoster { SharePoster(content) }

    public var texts: [String] {
        poster.texts + [artwork?.credit, brand, ShareCardBuilder.host].compactMap(\.self)
    }

    public var accessibilityLabel: String {
        ([poster.accessibilitySummary, artwork?.credit].compactMap(\.self))
            .joined(separator: ". ")
    }
}

enum HexColor {
    static func saturation(_ hex: String) -> Double {
        let text = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard text.count == 6, let value = UInt32(text, radix: 16) else { return 0 }
        let channels = [value >> 16, value >> 8, value].map { Double($0 & 255) / 255 }
        guard let high = channels.max(), let low = channels.min(), high > 0 else { return 0 }
        return (high - low) / high
    }
}

extension ArtWork {
    public var isPublicDomain: Bool {
        license.hasPrefix("PD") || licenseUrl.absoluteString.contains("publicdomain")
    }

    public var licenseLabel: String {
        isPublicDomain ? String(appLocalized: "Public domain") : license
    }

    public var archive: String {
        sourceUrl.host()?.contains("wikimedia") == true ? "Wikimedia Commons" : holder
    }
}
