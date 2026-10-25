import FiscalDesignSystem
import Lottie
import SwiftUI

struct PortraitArtView: View {
    let store: PortraitStore
    let request: PortraitRequest

    var body: some View {
        if request.isStill, let image = store.still(slug: request.slug, party: request.party) {
            Image(decorative: image, scale: 1)
                .resizable()
                .scaledToFill()
        } else if let animation = store.animation(slug: request.slug, party: request.party) {
            LottieView(animation: animation)
                .playbackMode(
                    request.isStill
                        ? .paused(at: .progress(0))
                        : .playing(.fromProgress(0, toProgress: 1, loopMode: .loop))
                )
                .resizable()
                .scaledToFill()
        }
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
