import CoreGraphics
import FeatureCore
import FiscalDesignSystem
import ImageIO
import SwiftUI

@MainActor
public enum ShareRenderer {
    public static let fileName = "Fiscal.png"

    public static func render(
        _ card: ShareCard, code: CGImage?, scale: CGFloat, portraits: PortraitArtwork? = nil
    ) -> ShareImage? {
        ShareImage(
            ShareCardView(card: card, code: code)
                .portraitArtwork(portraits)
                .portraitsStill()
                .partyMarksStill(),
            size: card.format.size, scale: scale, fileName: fileName)
    }
}

public struct RenderedCard {
    public let image: Image
    public let file: ShareImage

    public init?(file: ShareImage, scale: CGFloat) {
        guard let source = CGImageSourceCreateWithData(file.png as CFData, nil),
            let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }
        image = Image(decorative: cgImage, scale: scale)
        self.file = file
    }
}
