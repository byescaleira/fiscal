#if DEBUG
    import FeatureCore
    import FiscalDesignSystem
    import SwiftUI

    struct LabVote: Hashable, Identifiable {
        let id: String
        let house: String
        let proposition: String
        let date: String
        let yes: Int
        let no: Int
        let other: Int
        let total: Int
        let required: Int
        let requirement: String

        static let chamber = LabVote(
            id: "camara-2236186-60", house: "Câmara", proposition: "PLP 281/2019",
            date: "14 out. 2026", yes: 252, no: 176, other: 1, total: 513, required: 257,
            requirement: "maioria absoluta da Câmara")
        static let senate = LabVote(
            id: "senado-7107", house: "Senado", proposition: "PEC 221/2019", date: "14 out. 2026",
            yes: 75, no: 1, other: 3, total: 81, required: 49, requirement: "3/5 do Senado")
        static let all = [chamber, senate]

        var layout: HemicycleLayout {
            HemicycleLayout(yes: yes, no: no, other: other, total: total)
        }

        var absent: Int { max(total - yes - no - other, .zero) }

        var summary: String {
            "\(house), \(proposition), \(date): \(yes) sim, \(no) não, \(other) outros e \(absent) não votaram, de \(total). Eram precisos \(required) votos sim (\(requirement))."
        }
    }

    struct HemicycleGeometry {
        let center: CGPoint
        let outer: CGFloat
        let inner: CGFloat
        let rowWidth: CGFloat

        init(size: CGSize, rows: Int) {
            let outer = min(size.width / 2, size.height) * MetalLabPlenary.fill
            let inner = outer * HemicycleLayout.inner
            let rowWidth = (outer - inner) / CGFloat(max(rows, 1))
            self.outer = outer
            self.inner = inner
            self.rowWidth = rowWidth
            center = CGPoint(x: size.width / 2, y: outer + rowWidth / 2)
        }

        func point(row: Int, angle: Double) -> CGPoint {
            let radius = inner + (CGFloat(row) + 0.5) * rowWidth
            return CGPoint(
                x: center.x + cos(angle) * radius, y: center.y - sin(angle) * radius)
        }
    }

    enum MetalLabPlenary {
        static let fill: CGFloat = 0.94
        static let popSeats = 18.0
        static let popScale = 0.55
        static let dotShare = 0.38
        static let emptyShare = 0.22
    }

    struct PlenaryPrototype: View {
        enum Variant: String, CaseIterable, Identifiable {
            case shader = "Shader"
            case canvas = "Canvas"
            case today = "Hoje"
            var id: Self { self }
        }

        @State private var vote = LabVote.chamber
        @State private var variant = Variant.shader
        @State private var start = Date.now
        @State private var meter = FrameMeter()
        @State private var measuring = false

        var body: some View {
            MotionGateReader { gate in
                Form {
                    Section {
                        Picker(selection: $vote) {
                            ForEach(LabVote.all) { vote in
                                Text(verbatim: "\(vote.house) · \(vote.proposition)").tag(vote)
                            }
                        } label: {
                            Text(verbatim: "Votação")
                        }
                        ChoicePills(
                            "Desenho" as String, choices: Variant.allCases, selection: $variant,
                            label: \.rawValue)
                    }
                    Section {
                        PlenaryBoard(vote: vote, variant: variant, start: start, gate: gate)
                            .listRowInsets(
                                EdgeInsets(
                                    top: .spaceL, leading: .spaceL, bottom: .spaceL,
                                    trailing: .spaceL))
                        Button {
                            start = .now
                        } label: {
                            Text(verbatim: "Repetir a contagem")
                        }
                        .disabled(!gate.isOpen || variant == .today)
                    } footer: {
                        Text(
                            verbatim:
                                "Cada ponto é um parlamentar, em ordem de voto: sim da esquerda, não da direita, e no meio quem votou outra coisa ou não votou. A linha marca quantos sim eram precisos. Dado real da CDN do Fiscal (\(vote.id))."
                        )
                    }
                    Section {
                        Toggle(isOn: $measuring) { Text(verbatim: "Medir quadros") }
                        FrameMeterLabel(meter: meter, gate: gate)
                        if measuring { FrameTicker(meter: meter) }
                    }
                }
                .onChange(of: vote) { start = .now }
                .onChange(of: variant) { start = .now }
            }
            .navigationTitle(Text(verbatim: "Plenário"))
        }
    }

    private struct PlenaryBoard: View {
        let vote: LabVote
        let variant: PlenaryPrototype.Variant
        let start: Date
        let gate: MotionGate

        var body: some View {
            let layout = vote.layout
            VStack(alignment: .leading, spacing: .spaceM) {
                VStack(alignment: .leading, spacing: .space2XS) {
                    Text(verbatim: "\(vote.house) · \(vote.date)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(verbatim: vote.proposition)
                        .font(.emphasis(.title2, weight: .bold))
                }
                if variant == .today {
                    TallyBar(segments: [
                        .init(id: "yes", value: Double(vote.yes), color: .voteYes),
                        .init(id: "other", value: Double(vote.other), color: .voteAbstain),
                        .init(id: "no", value: Double(vote.no), color: .voteNo),
                    ])
                } else {
                    TimelineView(.animation(paused: !gate.isOpen)) { context in
                        let progress =
                            gate.isOpen
                            ? min(context.date.timeIntervalSince(start) / MetalLab.revealSeconds, 1)
                            : 1
                        let revealed = progress * Double(layout.lastRank + 1)
                        PlenaryDrawing(
                            layout: layout, vote: vote, variant: variant, revealed: revealed)
                    }
                    .aspectRatio(MetalLab.plenaryAspect, contentMode: .fit)
                }
                PlenaryLegend(vote: vote)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: vote.summary))
        }
    }

    private struct PlenaryDrawing: View {
        let layout: HemicycleLayout
        let vote: LabVote
        let variant: PlenaryPrototype.Variant
        let revealed: Double

        var body: some View {
            GeometryReader { proxy in
                let geometry = HemicycleGeometry(size: proxy.size, rows: layout.seatsPerRow.count)
                ZStack {
                    if variant == .shader {
                        Rectangle()
                            .fill(.white)
                            .colorEffect(
                                MetalLab.library.labHemicycle(
                                    .float2(geometry.center), .float(Float(geometry.outer)),
                                    .float(Float(geometry.inner)), .floatArray(layout.rowStarts),
                                    .floatArray(layout.shaderGroups),
                                    .floatArray(layout.shaderRanks),
                                    .float(Float(revealed)), .color(.voteYes), .color(.voteNo),
                                    .color(.voteAbstain), .color(.voteAbsent)))
                    } else {
                        Canvas { context, _ in
                            draw(in: &context, geometry: geometry)
                        }
                    }
                    MajorityMarker(
                        geometry: geometry, angle: layout.angle(beforeSeat: vote.required),
                        label: "\(vote.required) para aprovar")
                }
            }
        }

        private func draw(in context: inout GraphicsContext, geometry: HemicycleGeometry) {
            for (row, seats) in layout.seatsPerRow.enumerated() {
                let radius = geometry.inner + (CGFloat(row) + 0.5) * geometry.rowWidth
                let spacing = Double.pi / Double(seats)
                let base = min(geometry.rowWidth, radius * spacing) * MetalLabPlenary.dotShare
                for seat in layout.seats where seat.row == row {
                    let age = revealed - Double(seat.rank)
                    let pop =
                        age >= 0
                        ? 1 + MetalLabPlenary.popScale
                            * min(max(1 - age / MetalLabPlenary.popSeats, 0), 1) : 1
                    let size = base * pop
                    let center = geometry.point(row: row, angle: seat.angle)
                    let rect = CGRect(
                        x: center.x - size, y: center.y - size, width: size * 2, height: size * 2)
                    let color: Color =
                        age >= 0
                        ? seat.group.color : Color.voteAbsent.opacity(MetalLabPlenary.emptyShare)
                    context.fill(Path(ellipseIn: rect), with: .color(color))
                }
            }
        }
    }

    private struct MajorityMarker: View {
        let geometry: HemicycleGeometry
        let angle: Double
        let label: String

        var body: some View {
            let start = CGPoint(
                x: geometry.center.x + cos(angle) * (geometry.inner - geometry.rowWidth),
                y: geometry.center.y - sin(angle) * (geometry.inner - geometry.rowWidth))
            let end = CGPoint(
                x: geometry.center.x + cos(angle) * (geometry.outer + geometry.rowWidth),
                y: geometry.center.y - sin(angle) * (geometry.outer + geometry.rowWidth))
            ZStack {
                Path { path in
                    path.move(to: start)
                    path.addLine(to: end)
                }
                .stroke(
                    .primary,
                    style: StrokeStyle(
                        lineWidth: MetalLab.markerWidth, dash: [.space2XS, .space2XS]))
                Text(verbatim: label)
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .position(x: geometry.center.x, y: geometry.center.y - geometry.inner / 2)
            }
        }
    }

    private struct PlenaryLegend: View {
        let vote: LabVote

        var body: some View {
            HStack(spacing: .spaceM) {
                LegendItem(count: vote.yes, title: "sim", color: .voteYes)
                LegendItem(count: vote.no, title: "não", color: .voteNo)
                LegendItem(
                    count: vote.other, title: vote.other == 1 ? "outro" : "outros",
                    color: .voteAbstain)
                LegendItem(count: vote.absent, title: "não votaram", color: .voteAbsent)
            }
            .font(.footnote)
        }
    }

    private struct LegendItem: View {
        let count: Int
        let title: String
        let color: Color

        var body: some View {
            HStack(spacing: .space2XS) {
                Circle().fill(color).frame(width: .spaceS, height: .spaceS)
                Text(verbatim: "\(count) \(title)")
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize()
            }
        }
    }

    extension HemicycleLayout.Group {
        var color: Color {
            switch self {
            case .yes: .voteYes
            case .no: .voteNo
            case .other: .voteAbstain
            case .absent: .voteAbsent
            }
        }
    }

    struct FrameTicker: View {
        let meter: FrameMeter

        var body: some View {
            TimelineView(.animation) { context in
                Color.clear
                    .frame(height: .zero)
                    .onChange(of: context.date) { _, date in meter.tick(date) }
            }
            .onAppear { meter.reset() }
        }
    }
#endif
