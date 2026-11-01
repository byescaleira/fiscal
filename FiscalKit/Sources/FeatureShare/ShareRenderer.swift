import CoreGraphics
import FeatureCore
import FiscalDesignSystem
import ImageIO
import SwiftUI

@MainActor
public enum ShareRenderer {
    public static let brand = "Fiscal"
    public static let subjectLimit = 60

    public static func fileName(for content: ShareCardContent, extension suffix: String = "png")
        -> String
    {
        let cleaned = content.subjectTitle
            .components(separatedBy: CharacterSet(charactersIn: "/\\:"))
            .joined(separator: "-")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let subject = String(cleaned.prefix(subjectLimit))
            .trimmingCharacters(in: .whitespaces)
        let base = subject.isEmpty ? brand : "\(brand) - \(subject)"
        return "\(base).\(suffix)"
    }

    public static func render(
        _ card: ShareCard, code: CGImage?, scale: CGFloat, portraits: PortraitArtwork? = nil
    ) -> ShareImage? {
        ShareImage(
            frame(card, code: code, portraits: portraits),
            size: card.format.size, scale: scale, fileName: fileName(for: card.content))
    }

    public static func write(_ file: ShareImage) throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: file.fileName)
        try file.png.write(to: url, options: .atomic)
        return url
    }

    public static func frame(
        _ card: ShareCard, code: CGImage?, portraits: PortraitArtwork?, progress: Double = 1
    ) -> some View {
        ShareCardView(card: card, code: code)
            .environment(\.shareProgress, progress)
            .portraitArtwork(portraits)
            .portraitsStill()
            .partyMarksStill()
    }
}

extension ShareCardContent {
    public var subjectTitle: String {
        switch body {
        case .person, .expenses: faces.first?.name ?? headline ?? ""
        case .vote(let tally):
            tally.proposition.split(separator: "·").first.map {
                $0.trimmingCharacters(in: .whitespaces)
            } ?? headline ?? ""
        case .race, .victory, .representatives: headline ?? ""
        case .compare: faces.map(\.name).joined(separator: " x ")
        case .highlight(let highlight): highlight.title
        case .investigation(let investigation): investigation.question
        case .following: String(appLocalized: "Who I follow")
        }
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
