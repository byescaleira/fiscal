import FiscalDesignSystem
import SwiftUI

enum ShareZoneContent: Hashable {
    case faces([ShareFace])
    case shares([ShareSegment])
    case none
}

extension ShareCardContent {
    private static let zoneFaceLimit = 3

    var zoneContent: ShareZoneContent {
        switch body {
        case .vote(let tally):
            return .shares(tally.segments)
        case .race(let race):
            return .shares(
                race.candidates.map {
                    ShareSegment(share: $0.share, color: PartyPalette.of(party: $0.party).primary)
                })
        case .highlight(let highlight):
            if let tally = highlight.tally { return .shares(tally.segments) }
            return highlight.person.map { .faces([$0]) } ?? .none
        case .victory(let victory):
            return .faces([victory.winner])
        case .representatives:
            return .none
        default:
            let shown = Array(faces.prefix(Self.zoneFaceLimit))
            return shown.isEmpty ? .none : .faces(shown)
        }
    }
}

extension ShareTally {
    var segments: [ShareSegment] {
        [
            ShareSegment(share: yesShare, color: .voteYes),
            ShareSegment(share: noShare, color: .voteNo),
            ShareSegment(share: othersShare, color: .voteAbstain),
        ]
    }
}

struct ShareZoneArt: View {
    @Environment(\.shareProgress) private var progress
    @Environment(\.shareShowsArt) private var showsArt
    let content: ShareCardContent

    var body: some View {
        if showsArt {
            switch content.zoneContent {
            case .faces(let faces):
                HStack(spacing: .spaceM) {
                    ForEach(faces) { face in
                        PersonPortrait(
                            slug: face.slug, name: face.name, party: face.party,
                            size: faces.dropFirst().isEmpty
                                ? .shareZonePortrait : .shareZonePortraitPair)
                    }
                }
                .scaleEffect(
                    .shareNeighborScale + (1 - .shareNeighborScale) * ShareMotion.eased(progress)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .shares(let segments):
                GeometryReader { proxy in
                    HStack(spacing: .zero) {
                        ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                            segment.color.frame(
                                width: proxy.size.width
                                    * ShareMotion.fill(segment.share, progress: progress))
                        }
                        Spacer(minLength: .zero)
                    }
                }
            case .none:
                EmptyView()
            }
        }
    }
}
