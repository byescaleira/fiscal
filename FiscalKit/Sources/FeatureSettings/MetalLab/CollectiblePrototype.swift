#if DEBUG
    import FeatureCore
    import FiscalDesignSystem
    import SwiftUI

    struct CollectiblePrototype: View {
        enum Variant: String, CaseIterable, Identifiable {
            case card = "Carta"
            case frame = "Só moldura"
            case today = "Hoje"
            var id: Self { self }
        }

        @State private var variant = Variant.card
        @State private var turns = true
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
                        Toggle(isOn: $turns) { Text(verbatim: "Girar a carta") }
                    }
                    Section {
                        Group {
                            if variant == .today {
                                TodayCard(tilt: gate.isOpen ? tilt.tilt : .zero)
                            } else {
                                CollectibleCard(
                                    variant: variant, tilt: gate.isOpen ? tilt.tilt : .zero,
                                    turns: turns && gate.isOpen)
                            }
                        }
                        .gesture(
                            DragGesture()
                                .onChanged { tilt.drag($0.translation) }
                                .onEnded { _ in tilt.settle() }
                        )
                        .listRowInsets(
                            EdgeInsets(
                                top: .spaceXL, leading: .spaceXL, bottom: .spaceXL,
                                trailing: .spaceXL)
                        )
                        .listRowBackground(Color.clear)
                    } footer: {
                        Text(
                            verbatim:
                                "Incline o iPhone (ou arraste a carta). O efeito é igual para todo político: só o fundo do partido muda, como hoje. \(tilt.isLive ? "Sensor ligado." : "Sensor desligado.")"
                        )
                    }
                    Section {
                        Toggle(isOn: $measuring) { Text(verbatim: "Medir quadros") }
                        FrameMeterLabel(meter: meter, gate: gate)
                        if measuring { FrameTicker(meter: meter) }
                    }
                }
                .onChange(of: gate.isOpen, initial: true) { _, open in
                    if open { tilt.start() } else { tilt.stop() }
                }
                .onDisappear { tilt.stop() }
            }
            .navigationTitle(Text(verbatim: "Carta colecionável"))
        }
    }

    private enum CollectiblePerson {
        static let slug = "tabata-amaral"
        static let name = "Tabata Amaral"
        static let party = "PSB"
        static let office = "Deputada federal · SP"
        static let mandate = "Mandato 2023–2027"
        static let house = "Câmara dos Deputados"
    }

    private struct CollectibleCard: View {
        let variant: CollectiblePrototype.Variant
        let tilt: CGPoint
        let turns: Bool

        var body: some View {
            CardFace(variant: variant, tilt: tilt)
                .padding(MetalLab.collectibleFrame)
                .background { FoilLayer(tilt: tilt, metal: true) }
                .overlay { Glare(tilt: tilt) }
                .clipShape(.rect(cornerRadius: .radiusL))
                .aspectRatio(MetalLab.collectibleAspect, contentMode: .fit)
                .rotation3DEffect(
                    .degrees(turns ? tilt.x * MetalLab.collectibleTurn : .zero),
                    axis: (x: 0, y: 1, z: 0), perspective: MetalLab.collectiblePerspective
                )
                .rotation3DEffect(
                    .degrees(turns ? -tilt.y * MetalLab.collectibleTurn : .zero),
                    axis: (x: 1, y: 0, z: 0), perspective: MetalLab.collectiblePerspective
                )
                .environment(\.colorScheme, .dark)
                .accessibilityElement(children: .combine)
        }
    }

    private struct CardFace: View {
        let variant: CollectiblePrototype.Variant
        let tilt: CGPoint

        var body: some View {
            VStack(alignment: .leading, spacing: .spaceS) {
                HStack(spacing: .spaceS) {
                    Text(verbatim: CollectiblePerson.name)
                        .font(.emphasis(.title3, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(.opacitySoft * 2)
                    Spacer(minLength: .spaceXS)
                    PartyMark(CollectiblePerson.party)
                }
                ZStack {
                    PartyBackdrop(party: CollectiblePerson.party)
                    if variant == .card {
                        FoilLayer(tilt: tilt, metal: false).blendMode(.screen)
                    }
                    PersonPortrait(
                        slug: CollectiblePerson.slug, name: CollectiblePerson.name,
                        party: CollectiblePerson.party,
                        size: .medallion * MetalLab.collectibleArt
                    )
                    .overlay(Circle().strokeBorder(.white, lineWidth: .space2XS))
                }
                .frame(maxHeight: .infinity)
                .clipShape(.rect(cornerRadius: .radiusS))
                .overlay {
                    RoundedRectangle(cornerRadius: .radiusS)
                        .strokeBorder(.white.opacity(.opacitySoft), lineWidth: .space2XS)
                }
                VStack(alignment: .leading, spacing: .space2XS) {
                    Text(verbatim: CollectiblePerson.office).font(.headline)
                    Text(verbatim: CollectiblePerson.mandate)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.spaceS)
                .background(.black.opacity(.opacitySoft), in: .rect(cornerRadius: .radiusS))
                HStack {
                    Text(verbatim: "Fiscal").font(.caption2.bold())
                    Spacer()
                    Text(verbatim: CollectiblePerson.house).font(.caption2)
                }
                .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .padding(.spaceM)
            .background { PartyBackdrop(party: CollectiblePerson.party) }
            .clipShape(.rect(cornerRadius: .radiusM))
        }
    }

    private struct FoilLayer: View {
        let tilt: CGPoint
        let metal: Bool

        var body: some View {
            Rectangle()
                .fill(.black)
                .visualEffect { effect, proxy in
                    effect.colorEffect(
                        MetalLab.library.labCollectible(
                            .float2(proxy.size), .float2(tilt),
                            .float(
                                metal ? MetalLab.collectibleFrameFoil : MetalLab.collectibleFoil),
                            .float(MetalLab.collectibleSparkle), .float(metal ? 1 : 0)))
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private struct Glare: View {
        let tilt: CGPoint

        var body: some View {
            RadialGradient(
                colors: [.white.opacity(MetalLab.collectibleGlare), .clear],
                center: UnitPoint(
                    x: UnitPoint.center.x + tilt.x * MetalLab.collectibleGlareTravel,
                    y: UnitPoint.center.y + tilt.y * MetalLab.collectibleGlareTravel),
                startRadius: .zero,
                endRadius: .medallion * MetalLab.collectibleGlareRadius
            )
            .blendMode(.screen)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private struct TodayCard: View {
        let tilt: CGPoint

        var body: some View {
            VStack(spacing: .spaceL) {
                PersonPortrait(
                    slug: CollectiblePerson.slug, name: CollectiblePerson.name,
                    party: CollectiblePerson.party, size: .medallion
                )
                .overlay(Circle().strokeBorder(.white, lineWidth: .space2XS))
                VStack(spacing: .spaceXS) {
                    Text(verbatim: CollectiblePerson.name).font(.titleLarge)
                    Text(verbatim: CollectiblePerson.office)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.primary)
            .padding(.spaceXL)
            .frame(maxWidth: .infinity)
            .background {
                PartyBackdrop(party: CollectiblePerson.party)
                    .overlay {
                        Rectangle()
                            .fill(.black)
                            .visualEffect { effect, proxy in
                                effect.colorEffect(
                                    MetalLab.library.labSheen(
                                        .float2(proxy.size), .float2(tilt),
                                        .float(MetalLab.sheenStrength), .float(1)))
                            }
                            .blendMode(.screen)
                    }
                    .clipShape(.rect(cornerRadius: .radiusGroup))
            }
            .environment(\.colorScheme, .dark)
        }
    }
#endif
