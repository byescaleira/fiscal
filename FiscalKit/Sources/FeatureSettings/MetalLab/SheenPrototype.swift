#if DEBUG
    import FeatureCore
    import FiscalDesignSystem
    import SwiftUI

    struct SheenPrototype: View {
        enum Variant: String, CaseIterable, Identifiable {
            case light = "Brilho"
            case holographic = "Holográfico"
            case today = "Hoje"
            var id: Self { self }
        }

        @State private var variant = Variant.light
        @State private var tilt = TiltSource()
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
                        SheenCard(variant: variant, tilt: tilt.tilt, isOn: gate.isOpen)
                            .gesture(
                                DragGesture()
                                    .onChanged { tilt.drag($0.translation) }
                                    .onEnded { _ in tilt.settle() }
                            )
                            .listRowInsets(
                                EdgeInsets(
                                    top: .spaceL, leading: .spaceL, bottom: .spaceL,
                                    trailing: .spaceL))
                    } footer: {
                        Text(
                            verbatim:
                                "Incline o iPhone (ou arraste o cartão). O brilho é igual para todo político e partido e não muda cor, ordem nem tamanho. A leitura do movimento para fora desta tela e com Reduzir movimento, Pouca Energia ou o aparelho quente. \(tilt.isLive ? "Sensor ligado." : "Sensor desligado.")"
                        )
                    }
                    Section {
                        Toggle(isOn: $measuring) { Text(verbatim: "Medir quadros") }
                        FrameMeterLabel(meter: meter, gate: gate)
                        if measuring { FrameTicker(meter: meter) }
                    }
                }
                .onChange(of: gate.isOpen && variant != .today, initial: true) { _, follows in
                    if follows { tilt.start() } else { tilt.stop() }
                }
                .onDisappear { tilt.stop() }
            }
            .navigationTitle(Text(verbatim: "Brilho na inclinação"))
        }
    }

    private struct SheenCard: View {
        let variant: SheenPrototype.Variant
        let tilt: CGPoint
        let isOn: Bool

        static let person = (
            slug: "acacio-favacho", name: "Acácio Favacho", party: "MDB", place: "AP"
        )

        var body: some View {
            let person = Self.person
            VStack(alignment: .leading, spacing: .spaceM) {
                PersonPortrait(
                    slug: person.slug, name: person.name, party: person.party,
                    size: .portraitAnimated)
                VStack(alignment: .leading, spacing: .space2XS) {
                    Text(verbatim: person.name)
                        .font(.emphasis(.title2, weight: .bold))
                    Text(verbatim: "Deputado federal · \(person.party)-\(person.place)")
                        .font(.subheadline)
                        .opacity(.opacityStrong)
                }
            }
            .foregroundStyle(.white)
            .padding(.spaceXL)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { PartyBackdrop(party: person.party) }
            .overlay {
                if variant != .today {
                    Rectangle()
                        .fill(.black)
                        .visualEffect { effect, proxy in
                            effect.colorEffect(
                                MetalLab.library.labSheen(
                                    .float2(proxy.size), .float2(tilt),
                                    .float(MetalLab.sheenStrength),
                                    .float(variant == .holographic ? 1 : 0)))
                        }
                        .blendMode(.screen)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .clipShape(.rect(cornerRadius: .radiusGroup))
            .accessibilityElement(children: .combine)
        }
    }
#endif
