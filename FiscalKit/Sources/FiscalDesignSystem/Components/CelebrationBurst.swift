import SwiftUI

public struct CelebrationBurst: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date.now
    private let colors: [Color]
    private let pieces = 36
    private let duration: Double = 3

    public init(colors: [Color]) {
        self.colors = colors.isEmpty ? [.white] : colors
    }

    public var body: some View {
        if !reduceMotion {
            TimelineView(.animation(paused: Date.now.timeIntervalSince(start) > duration)) {
                timeline in
                Canvas { context, size in
                    let elapsed = timeline.date.timeIntervalSince(start)
                    guard elapsed < duration else { return }
                    let progress = elapsed / duration
                    for index in 0..<pieces {
                        let seed = Double(index)
                        let angle = seed * 2.399963
                        let spread = 0.3 + (seed.truncatingRemainder(dividingBy: 7)) / 10
                        let x = size.width / 2 + cos(angle) * size.width * spread * progress
                        let y =
                            size.height * 0.35 + sin(angle) * size.height * spread * progress * 0.6
                            + size.height * progress * progress * 0.8
                        let rect = CGRect(x: x, y: y, width: 7, height: 12)
                        var piece = context
                        piece.opacity = 1 - progress
                        piece.translateBy(x: rect.midX, y: rect.midY)
                        piece.rotate(by: .radians(angle + progress * 8))
                        piece.fill(
                            Path(
                                roundedRect: CGRect(x: -3.5, y: -6, width: 7, height: 12),
                                cornerRadius: 2),
                            with: .color(colors[index % colors.count]))
                    }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}
