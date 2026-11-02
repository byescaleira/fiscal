import CoreGraphics
import FeatureCore
import FiscalDesignSystem
import ImageIO
import SwiftUI

@MainActor
public enum ShareRenderer {
    public static let brand = "Fiscal"
    public static let subjectLimit = 60
    public static let videoScale: CGFloat = 3
    public static let videoSeconds = 5.0
    public static let videoFPS = 30

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
        _ card: ShareCard, code: CGImage?, scale: CGFloat
    ) -> ShareImage? {
        ShareImage(
            frame(card, code: code),
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

    public static func video(
        _ card: ShareCard, code: CGImage?, progress: (Double) -> Void
    ) async throws -> URL {
        try await ShareVideoRenderer.render(
            size: card.format.size, scale: videoScale, seconds: videoSeconds, fps: videoFPS,
            fileName: fileName(for: card.content, extension: "mp4"),
            frame: { AnyView(frame(card, code: code, progress: $0)) },
            progress: progress)
    }

    public static func frame(
        _ card: ShareCard, code: CGImage?, progress: Double = 1
    ) -> some View {
        ShareCardView(card: card, code: code)
            .environment(\.shareProgress, progress)
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
        case .receipt(let receipt): receipt.supplier
        case .ballot(let ballot): ballot.proposition
        case .proposal(let proposal): proposal.reference
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
