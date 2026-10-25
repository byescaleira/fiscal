import CoreGraphics
import SwiftUI

@MainActor
public enum ShareRenderer {
    public static func render(_ card: ShareCard, code: CGImage?, scale: CGFloat) -> CGImage? {
        let renderer = ImageRenderer(content: ShareCardView(card: card, code: code))
        renderer.scale = scale
        renderer.proposedSize = ProposedViewSize(card.format.size)
        renderer.isOpaque = true
        return renderer.cgImage
    }
}

public struct RenderedCard {
    public let image: Image
    public let pixels: CGSize

    public init(cgImage: CGImage, scale: CGFloat) {
        image = Image(decorative: cgImage, scale: scale)
        pixels = CGSize(width: cgImage.width, height: cgImage.height)
    }
}
