import FiscalDesignSystem
import Lottie
import SwiftUI

struct PortraitArtView: View {
    private static let firstGesture: ClosedRange<Double> = 2...14
    private static let nextGesture: ClosedRange<Double> = 6...14

    let store: PortraitStore
    let request: PortraitRequest
    @State private var settled: PortraitExpression?
    @State private var gesture: PortraitGesture?
    @State private var isVisible = true

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
            let playsExpression = expression != nil && settled != expression
            LottieView(animation: animation)
                .playbackMode(playback)
                .animationDidFinish { completed in
                    guard completed else { return }
                    if playsExpression { settled = expression } else { gesture = nil }
                }
                .resizable()
                .scaledToFill()
                .onChange(of: expression) {
                    settled = nil
                    gesture = nil
                }
                .onScrollVisibilityChange { isVisible = $0 }
                .onAppear { isVisible = true }
                .onDisappear { isVisible = false }
                .task(id: gesturesAreOn) { await fidget() }
        }
    }

    private var playback: LottiePlaybackMode {
        if request.isStill { return .paused(at: .progress(0)) }
        if !isVisible { return .paused(at: .currentFrame) }
        if let expression = request.expression {
            if settled != expression {
                return .playing(.marker(expression.marker, loopMode: .playOnce))
            }
            if let loop = expression.loopMarker {
                return .playing(.marker(loop, loopMode: .loop))
            }
        }
        if let gesture {
            return .playing(.marker(gesture.rawValue, loopMode: .playOnce))
        }
        return .playing(.marker(PortraitExpression.idleMarker, loopMode: .loop))
    }

    private var gesturesAreOn: Bool {
        guard request.allowsGestures, !request.isStill, isVisible else { return false }
        guard let expression = request.expression else { return true }
        return settled == expression && expression.loopMarker == nil
    }

    private func fidget() async {
        guard gesturesAreOn else { return }
        var delay = Double.random(in: Self.firstGesture)
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            if gesture == nil { gesture = PortraitGesture.allCases.randomElement() }
            delay = Double.random(in: Self.nextGesture)
        }
    }
}

enum PortraitGesture: String, CaseIterable {
    case lookAround, tilt, browRaise, doubleBlink, settle
}

extension View {
    public func fiscalPortraits(_ store: PortraitStore) -> some View {
        environment(store)
            .portraitArtwork(
                PortraitArtwork { request in
                    guard store.drawsPortraits else { return nil }
                    return AnyView(PortraitArtView(store: store, request: request))
                })
    }
}
