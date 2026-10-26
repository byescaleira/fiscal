import FiscalDesignSystem
import Lottie
import SwiftUI

struct PortraitArtView: View {
    let store: PortraitStore
    let request: PortraitRequest
    @State private var settled: PortraitExpression?

    var body: some View {
        if request.isStill,
            let image = store.still(
                slug: request.slug, party: request.party, pose: request.expression)
        {
            Image(decorative: image, scale: 1)
                .resizable()
                .scaledToFill()
        } else if let animation = store.animation(slug: request.slug, party: request.party) {
            let expression = request.expression
            LottieView(animation: animation)
                .playbackMode(playback)
                .animationDidFinish { completed in
                    if completed { settled = expression }
                }
                .resizable()
                .scaledToFill()
                .onChange(of: expression) { settled = nil }
        }
    }

    private var playback: LottiePlaybackMode {
        if request.isStill { return .paused(at: .progress(0)) }
        guard let expression = request.expression else {
            return .playing(.marker(PortraitExpression.idleMarker, loopMode: .loop))
        }
        guard settled == expression else {
            return .playing(.marker(expression.marker, loopMode: .playOnce))
        }
        return .playing(
            .marker(expression.loopMarker ?? PortraitExpression.idleMarker, loopMode: .loop))
    }
}

extension View {
    public func fiscalPortraits(_ store: PortraitStore) -> some View {
        environment(store)
            .portraitArtwork(
                PortraitArtwork { request in
                    guard store.hasPortrait(slug: request.slug, party: request.party) else {
                        return nil
                    }
                    return AnyView(PortraitArtView(store: store, request: request))
                })
    }
}
