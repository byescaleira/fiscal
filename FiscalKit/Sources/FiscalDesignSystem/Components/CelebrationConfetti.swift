import SwiftUI

public struct CelebrationConfetti: View {
    private static let pieces = 30
    private static let sweep: CGFloat = 1.24
    private static let inner: CGFloat = 0.6
    private static let pieceWidth: CGFloat = 0.024
    private static let pieceHeight: CGFloat = 0.042
    private static let scatter = 0.618
    private static let spin: CGFloat = 3
    private let colors: [Color]

    public init(colors: [Color]) {
        self.colors = colors.isEmpty ? [.white] : colors
    }

    public var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let width = side * Self.pieceWidth
            let height = side * Self.pieceHeight
            let start = CGFloat.pi * (1 - (Self.sweep - 1) / 2)
            for index in 0..<Self.pieces {
                let seed = CGFloat(index)
                let fraction = seed / CGFloat(Self.pieces - 1)
                let angle = start + .pi * Self.sweep * fraction
                let jitter = CGFloat(
                    (Double(index) * Self.scatter).truncatingRemainder(dividingBy: 1))
                let radius = side / 2 * (Self.inner + (1 - Self.inner) * jitter)
                var piece = context
                piece.translateBy(
                    x: size.width / 2 + cos(angle) * radius,
                    y: size.height / 2 + sin(angle) * radius)
                piece.rotate(by: .radians(Double(angle * Self.spin + seed)))
                piece.fill(
                    Path(
                        roundedRect: CGRect(
                            x: -width / 2, y: -height / 2, width: width, height: height),
                        cornerRadius: width / 3),
                    with: .color(colors[index % colors.count]))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
