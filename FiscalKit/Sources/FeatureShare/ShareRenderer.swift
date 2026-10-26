import CoreGraphics
import CoreTransferable
import FiscalDesignSystem
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

@MainActor
public enum ShareRenderer {
    public static func render(
        _ card: ShareCard, code: CGImage?, scale: CGFloat, portraits: PortraitArtwork? = nil
    ) -> CGImage? {
        let renderer = ImageRenderer(
            content: ShareCardView(card: card, code: code)
                .portraitArtwork(portraits)
                .portraitsStill()
                .partyMarksStill())
        renderer.scale = scale
        renderer.proposedSize = ProposedViewSize(card.format.size)
        renderer.isOpaque = true
        return renderer.cgImage
    }
}

public struct RenderedCard {
    public let image: Image
    public let pixels: CGSize
    public let file: ShareCardFile

    public init(cgImage: CGImage, scale: CGFloat) {
        image = Image(decorative: cgImage, scale: scale)
        pixels = CGSize(width: cgImage.width, height: cgImage.height)
        file = ShareCardFile(png: Self.png(cgImage))
    }

    private static func png(_ cgImage: CGImage) -> Data {
        let data = NSMutableData()
        guard
            let destination = CGImageDestinationCreateWithData(
                data, UTType.png.identifier as CFString, 1, nil)
        else { return Data() }
        CGImageDestinationAddImage(destination, cgImage, nil)
        CGImageDestinationFinalize(destination)
        return data as Data
    }
}

public struct ShareCardFile: Transferable, Sendable {
    public let png: Data

    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { $0.png }
            .suggestedFileName("Fiscal.png")
    }
}
