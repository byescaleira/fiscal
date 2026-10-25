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

    public var shade: String? { palette.first }

    public var glow: String? { palette.dropFirst().first ?? palette.first }
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

    public var portraitMark: String? {
        content.hasPortrait ? String(appLocalized: "Illustration by Fiscal") : nil
    }

    public var texts: [String] {
        content.texts
            + [artwork?.credit, portraitMark, brand, ShareCardBuilder.host]
            .compactMap(\.self)
    }

    public var accessibilityLabel: String {
        ([content.accessibilitySummary, artwork?.credit].compactMap(\.self))
            .joined(separator: ". ")
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
