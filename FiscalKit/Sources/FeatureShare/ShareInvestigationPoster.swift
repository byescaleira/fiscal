import CoreGraphics
import FiscalDesignSystem
import SwiftUI

extension ShareFormat {
    var casePortrait: CGFloat {
        switch self {
        case .stories: .posterCasePortraitStories
        case .feed: .posterCasePortraitFeed
        case .message: .posterCasePortraitMessage
        }
    }

    var caseNumber: CGFloat {
        switch self {
        case .stories: .posterCaseNumberStories
        case .feed: .posterCaseNumberFeed
        case .message: .posterCaseNumberMessage
        }
    }

    var caseQuestionLines: Int {
        switch self {
        case .stories: 5
        case .feed: 3
        case .message: 2
        }
    }

    func caseQuestionSize(for text: String) -> CGFloat {
        let base: CGFloat =
            switch self {
            case .stories: .posterCaseQuestionStories
            case .feed: .posterCaseQuestionFeed
            case .message: .posterCaseQuestionMessage
            }
        let characters = CGFloat(max(text.count, 1))
        let fitting =
            CGFloat(caseQuestionLines) * contentWidth / (characters * .posterCaseAdvance)
        return min(base, max(.posterCaseQuestionMinimum, fitting))
    }
}

struct ShareInvestigationPoster: View {
    let card: ShareCard
    let investigation: ShareInvestigation
    let code: CGImage?

    var body: some View {
        let format = card.format
        VStack(alignment: .leading, spacing: format == .message ? .spaceS : .spaceM) {
            ShareInvestigationHero(investigation: investigation, format: format)
            Spacer(minLength: .zero)
            ShareCaseReading(investigation: investigation, format: format)
                .fixedSize(horizontal: false, vertical: true)
            ShareCaseFooter(card: card, code: code)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(format.margin)
        .background { ShareCaseField() }
        .clipped()
    }
}

private struct ShareCaseField: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.scoreboard.mix(with: .white, by: .opacityPosterGlow), .scoreboard],
                startPoint: .top, endPoint: .bottom)
            Canvas { context, size in
                let step = CGFloat.posterCaseGrid
                var y = step
                while y < size.height {
                    var x = step
                    while x < size.width {
                        let dot = CGRect(
                            x: x, y: y, width: .posterCaseDot, height: .posterCaseDot)
                        context.fill(
                            Path(ellipseIn: dot), with: .color(.white.opacity(.opacityCaseGrid)))
                        x += step
                    }
                    y += step
                }
            }
        }
        .accessibilityHidden(true)
    }
}

struct ShareInvestigationHero: View {
    let investigation: ShareInvestigation
    let format: ShareFormat

    var body: some View {
        VStack(alignment: .leading, spacing: format == .message ? .spaceS : .spaceM) {
            HStack(spacing: .spaceXS) {
                Image(systemName: "magnifyingglass")
                Text("INVESTIGATION")
                    .tracking(.posterTracking)
            }
            .font(.posterVictoryChipCompact)
            .padding(.horizontal, .spaceS)
            .padding(.vertical, .space2XS)
            .background(.white.opacity(.opacityTint), in: .capsule)
            Text(verbatim: "“\(investigation.question)”")
                .font(.posterTitle(format.caseQuestionSize(for: investigation.question)))
                .lineLimit(format.caseQuestionLines)
                .minimumScaleFactor(.posterShrink)
                .fixedSize(horizontal: false, vertical: true)
            if !investigation.faces.isEmpty, format != .message {
                ShareCaseThread(faces: investigation.faces, format: format)
            }
        }
    }
}

private struct ShareCaseThread: View {
    let faces: [ShareFace]
    let format: ShareFormat

    var body: some View {
        let size = format.casePortrait
        HStack(spacing: .spaceS) {
            ForEach(faces) { face in
                PersonPortrait(slug: face.slug, name: face.name, party: face.party, size: size)
                    .overlay { Circle().strokeBorder(.white, lineWidth: .spaceHairline) }
            }
            if faces.count == 1, let face = faces.first {
                ShareIdentity(name: face.name, party: face.party)
            }
        }
        .background(alignment: .leading) {
            if faces.count > 1 {
                Rectangle()
                    .fill(Color.scoreboardAccent)
                    .frame(height: .posterCaseThread)
                    .padding(.horizontal, size / 2)
            }
        }
    }
}

private struct ShareCaseReading: View {
    let investigation: ShareInvestigation
    let format: ShareFormat

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            Text("READING")
                .font(.posterEyebrow)
                .tracking(.posterTracking)
                .foregroundStyle(Color.scoreboardAccent)
            Text(verbatim: investigation.conclusion)
                .font(format == .message ? .posterHeadlineCompact : .posterHeadline)
                .lineLimit(format == .stories ? 4 : 2)
                .minimumScaleFactor(.shareTextShrink)
                .fixedSize(horizontal: false, vertical: true)
            let numbers = investigation.numbers(for: format)
            if !numbers.isEmpty {
                HStack(alignment: .top, spacing: .spaceL) {
                    ForEach(numbers) { number in
                        VStack(alignment: .leading, spacing: .zero) {
                            ShareFigure(value: number.value, size: format.caseNumber)
                            Text(verbatim: number.label)
                                .font(.posterLabel)
                                .foregroundStyle(Color.posterSecondary)
                                .lineLimit(2)
                                .minimumScaleFactor(.shareTextShrink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.top, .space2XS)
            }
            if let compared = investigation.compared, format == .stories {
                ShareCaseNote(symbol: "arrow.left.arrow.right", text: compared)
            }
            if let uncertainty = investigation.uncertainty {
                ShareCaseNote(symbol: "questionmark.circle", text: uncertainty)
            }
        }
    }
}

private struct ShareCaseNote: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: .spaceXS) {
            Image(systemName: symbol)
            Text(verbatim: text)
                .lineLimit(2)
                .minimumScaleFactor(.shareTextShrink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.posterLabel)
        .foregroundStyle(Color.posterSecondary)
    }
}

private struct ShareCaseFooter: View {
    let card: ShareCard
    let code: CGImage?

    var body: some View {
        HStack(alignment: .bottom, spacing: .spaceM) {
            VStack(alignment: .leading, spacing: .space2XS) {
                Text(verbatim: card.content.source)
                    .font(.posterSource)
                    .foregroundStyle(Color.posterSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(.shareTextShrink)
                Text(verbatim: card.content.stamp)
                    .font(.shareStamp)
                    .foregroundStyle(Color.posterSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(.shareTextShrink)
                HStack(alignment: .firstTextBaseline, spacing: .spaceXS) {
                    Text(verbatim: card.brand)
                        .font(.posterBrand)
                    Text(verbatim: ShareCardBuilder.host)
                        .font(.posterHost)
                        .foregroundStyle(Color.posterSecondary)
                }
                .lineLimit(1)
            }
            Spacer(minLength: .zero)
            if let code, card.format.showsCode {
                Image(decorative: code, scale: 1)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: .posterCode, height: .posterCode)
                    .padding(.posterCodeInset)
                    .background(.white, in: .rect(cornerRadius: .space2XS))
            }
        }
    }
}
