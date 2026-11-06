import SwiftUI

public struct PlenaryColors: Sendable {
    public let yes: Color
    public let no: Color
    public let other: Color
    public let absent: Color
    public let track: Color
    public let ink: Color

    public init(yes: Color, no: Color, other: Color, absent: Color, track: Color, ink: Color) {
        self.yes = yes
        self.no = no
        self.other = other
        self.absent = absent
        self.track = track
        self.ink = ink
    }

    public func color(for group: HemicycleLayout.Group) -> Color {
        switch group {
        case .yes: yes
        case .no: no
        case .other: other
        case .absent: absent
        }
    }
}

public struct PlenaryChart: View {
    private let layout: HemicycleLayout
    private let colors: PlenaryColors
    private let requiredYes: Int?
    private let animates: Bool
    @State private var start: Date?
    @State private var isFinished = false

    public init(layout: HemicycleLayout, colors: PlenaryColors, requiredYes: Int?, animates: Bool) {
        self.layout = layout
        self.colors = colors
        self.requiredYes = requiredYes
        self.animates = animates
    }

    public var body: some View {
        let running = animates && !isFinished
        TimelineView(.animation(paused: !running)) { context in
            Canvas { canvas, size in
                let geometry = HemicycleGeometry(size: size, rows: layout.seatsPerRow.count)
                drawSeats(
                    in: &canvas, geometry: geometry,
                    revealed: revealed(at: context.date, running: running))
                if let requiredYes {
                    drawMarker(in: &canvas, geometry: geometry, required: requiredYes)
                }
            }
        }
        .aspectRatio(.plenaryAspect, contentMode: .fit)
        .onAppear {
            if animates, start == nil { start = .now }
        }
        .task(id: start) {
            guard let start, !isFinished else { return }
            let remaining = Double.plenaryRevealSeconds - Date.now.timeIntervalSince(start)
            if remaining > 0 { try? await Task.sleep(for: .seconds(remaining)) }
            guard !Task.isCancelled else { return }
            isFinished = true
        }
        .accessibilityHidden(true)
    }

    private func revealed(at date: Date, running: Bool) -> Double {
        let total = Double(layout.lastRank + 1)
        guard running else { return total }
        guard let start else { return .zero }
        return min(max(date.timeIntervalSince(start) / .plenaryRevealSeconds, 0), 1) * total
    }

    private func drawSeats(
        in canvas: inout GraphicsContext, geometry: HemicycleGeometry, revealed: Double
    ) {
        let total = Double(layout.lastRank + 1)
        for seat in layout.seats {
            let radius = geometry.radius(row: seat.row)
            let spacing = Double.pi / Double(layout.seatsPerRow[seat.row])
            let base = min(geometry.rowWidth, radius * spacing) * .plenaryDot
            let age = revealed - Double(seat.rank)
            let isLit = age >= 0 || revealed >= total
            let pop =
                isLit && revealed < total
                ? 1 + .plenaryPop * min(max(1 - age / .plenaryPopSeats, 0), 1) : 1
            let size = base * pop
            let center = geometry.point(row: seat.row, angle: seat.angle)
            let dot = CGRect(
                x: center.x - size, y: center.y - size, width: size * 2, height: size * 2)
            let fill = isLit ? colors.color(for: seat.group) : colors.track.opacity(.opacityTint)
            canvas.fill(Path(ellipseIn: dot), with: .color(fill))
        }
    }

    private func drawMarker(
        in canvas: inout GraphicsContext, geometry: HemicycleGeometry, required: Int
    ) {
        let angle = layout.angle(beforeSeat: required)
        let start = geometry.point(radius: geometry.inner - geometry.rowWidth / 2, angle: angle)
        let end = geometry.point(radius: geometry.outer + geometry.rowWidth / 2, angle: angle)
        var line = Path()
        line.move(to: start)
        line.addLine(to: end)
        canvas.stroke(
            line, with: .color(colors.ink),
            style: StrokeStyle(lineWidth: .plenaryMarkerWidth, dash: [.space2XS, .space2XS]))
        let label = Text("\(required) to pass")
            .font(.caption.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(colors.ink)
        canvas.draw(label, at: geometry.center, anchor: .bottom)
    }
}

struct HemicycleGeometry {
    let center: CGPoint
    let outer: CGFloat
    let inner: CGFloat
    let rowWidth: CGFloat

    init(size: CGSize, rows: Int) {
        let outer = min(size.width / 2, size.height) * .plenaryFill
        let inner = outer * HemicycleLayout.inner
        let rowWidth = (outer - inner) / CGFloat(max(rows, 1))
        self.outer = outer
        self.inner = inner
        self.rowWidth = rowWidth
        center = CGPoint(x: size.width / 2, y: outer + rowWidth / 2)
    }

    func radius(row: Int) -> CGFloat {
        inner + (CGFloat(row) + 0.5) * rowWidth
    }

    func point(row: Int, angle: Double) -> CGPoint {
        point(radius: radius(row: row), angle: angle)
    }

    func point(radius: CGFloat, angle: Double) -> CGPoint {
        CGPoint(x: center.x + cos(angle) * radius, y: center.y - sin(angle) * radius)
    }
}
