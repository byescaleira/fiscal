#if DEBUG
    import FeatureCore
    import FiscalDesignSystem
    import SwiftUI

    struct LikePrototype: View {
        enum Variant: String, CaseIterable, Identifiable {
            case ripple = "Onda"
            case burst = "Partículas"
            case today = "Hoje"
            var id: Self { self }
        }

        @State private var variant = Variant.ripple
        @State private var meter = FrameMeter()
        @State private var measuring = false

        var body: some View {
            MotionGateReader { gate in
                Form {
                    Section {
                        ChoicePills(
                            "Efeito" as String, choices: Variant.allCases, selection: $variant,
                            label: \.rawValue)
                    }
                    Section {
                        LikeCard(variant: variant, gate: gate)
                            .listRowInsets(EdgeInsets())
                    } footer: {
                        Text(
                            verbatim:
                                "Toque no coração ou dois toques no cartão. A onda sai de onde você tocou e o shader só roda durante a animação. Com Reduzir movimento, Pouca Energia ou o aparelho quente, só o coração muda."
                        )
                    }
                    Section {
                        Toggle(isOn: $measuring) { Text(verbatim: "Medir quadros") }
                        FrameMeterLabel(meter: meter, gate: gate)
                        if measuring { FrameTicker(meter: meter) }
                    }
                }
            }
            .navigationTitle(Text(verbatim: "Curtir"))
        }
    }

    private struct LikeCard: View {
        let variant: LikePrototype.Variant
        let gate: MotionGate
        @State private var liked = false
        @State private var ripples = 0
        @State private var bursts = 0
        @State private var origin = CGPoint.zero
        @State private var heart = CGPoint.zero

        var body: some View {
            let vote = LabVote.chamber
            VStack(alignment: .leading, spacing: .spaceM) {
                Text(verbatim: "\(vote.house) · \(vote.date)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(verbatim: vote.proposition)
                    .font(.emphasis(.title3, weight: .bold))
                Text(
                    verbatim:
                        "Trata dos regimes de resolução das instituições autorizadas a funcionar pelo Banco Central do Brasil."
                )
                .font(.body)
                TallyBar(segments: [
                    .init(id: "yes", value: Double(vote.yes), color: .voteYes),
                    .init(id: "other", value: Double(vote.other), color: .voteAbstain),
                    .init(id: "no", value: Double(vote.no), color: .voteNo),
                ])
                HStack {
                    Text(
                        verbatim: "\(vote.yes) sim · \(vote.no) não · precisava de \(vote.required)"
                    )
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    Spacer()
                    LikeButton(
                        liked: liked, bursts: bursts, animates: variant != .today && gate.isOpen
                    ) {
                        toggle(from: heart)
                    }
                    .onGeometryChange(for: CGPoint.self) { proxy in
                        let frame = proxy.frame(in: .named(MetalLab.likeSpace))
                        return CGPoint(x: frame.midX, y: frame.midY)
                    } action: {
                        heart = $0
                    }
                }
            }
            .padding(.spaceL)
            .background(.background)
            .contentShape(.rect)
            .onTapGesture(count: 2, coordinateSpace: .named(MetalLab.likeSpace)) { location in
                if !liked { toggle(from: location) }
            }
            .coordinateSpace(.named(MetalLab.likeSpace))
            .modifier(
                RippleModifier(
                    origin: origin, trigger: ripples, isOn: variant == .ripple && gate.isOpen)
            )
            .sensoryFeedback(.impact(weight: .light), trigger: liked) { _, now in now }
        }

        private func toggle(from point: CGPoint) {
            liked.toggle()
            guard liked else { return }
            origin = point
            ripples += 1
            bursts += 1
        }
    }

    private struct LikeButton: View {
        let liked: Bool
        let bursts: Int
        let animates: Bool
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                Image(systemName: liked ? "heart.fill" : "heart")
                    .font(.title2)
                    .foregroundStyle(liked ? Color.retroRust : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
                    .quietBounce(value: liked)
                    .frame(width: .badgeL, height: .badgeL)
            }
            .buttonStyle(.plain)
            .overlay {
                if animates {
                    BurstOverlay(trigger: bursts)
                }
            }
            .accessibilityLabel(Text(verbatim: liked ? "Descurtir" : "Curtir"))
        }
    }

    private struct BurstOverlay: View {
        let trigger: Int

        var body: some View {
            Rectangle()
                .fill(.white)
                .frame(width: .badgeXL * 2, height: .badgeXL * 2)
                .keyframeAnimator(initialValue: 0.0, trigger: trigger) { view, elapsed in
                    view.visualEffect { effect, proxy in
                        effect.colorEffect(
                            MetalLab.library.labBurst(
                                .float2(proxy.size), .float(Float(elapsed)),
                                .float(Float(MetalLab.burstDuration)), .color(.retroRust)),
                            isEnabled: elapsed > 0 && elapsed < MetalLab.burstDuration)
                    }
                    .opacity(elapsed > 0 && elapsed < MetalLab.burstDuration ? 1 : 0)
                } keyframes: { _ in
                    MoveKeyframe(0)
                    LinearKeyframe(MetalLab.burstDuration, duration: MetalLab.burstDuration)
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private struct RippleModifier: ViewModifier {
        let origin: CGPoint
        let trigger: Int
        let isOn: Bool

        func body(content: Content) -> some View {
            if isOn {
                content.keyframeAnimator(initialValue: 0.0, trigger: trigger) { view, elapsed in
                    view.layerEffect(
                        MetalLab.library.labRipple(
                            .float2(origin), .float(Float(elapsed)),
                            .float(MetalLab.rippleAmplitude),
                            .float(MetalLab.rippleFrequency), .float(MetalLab.rippleDecay),
                            .float(MetalLab.rippleSpeed)),
                        maxSampleOffset: MetalLab.rippleOffset,
                        isEnabled: elapsed > 0 && elapsed < MetalLab.rippleDuration)
                } keyframes: { _ in
                    MoveKeyframe(0)
                    LinearKeyframe(MetalLab.rippleDuration, duration: MetalLab.rippleDuration)
                }
            } else {
                content
            }
        }
    }
#endif
