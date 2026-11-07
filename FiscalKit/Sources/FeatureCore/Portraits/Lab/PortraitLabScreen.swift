#if DEBUG
    import FiscalDesignSystem
    import FiscalResource
    import SwiftUI

    enum PortraitLabPerson: String, CaseIterable, Identifiable, Sendable {
        case riedel = "eduardo-riedel"
        case lula
        case tabata = "tabata-amaral"
        case neutral = "pessoa-sem-tracos"

        var id: Self { self }

        var slug: String { rawValue }

        var party: String {
            switch self {
            case .riedel: "PP"
            case .lula: "PT"
            case .tabata: "PSB"
            case .neutral: "PSD"
            }
        }

        var name: String {
            switch self {
            case .riedel: "Eduardo Riedel"
            case .lula: "Lula"
            case .tabata: "Tabata Amaral"
            case .neutral: "Rosto neutro"
            }
        }
    }

    enum PortraitLabError: Error, Equatable {
        case noRig
        case unsupported(String)
    }

    @MainActor
    @Observable
    final class PortraitLabModel {
        let store: PortraitStore
        let renderer: Result<MetalPortraitRenderer, MetalPortraitError>
        let benchmark = PortraitBenchmark()
        let tilt = PortraitTilt()
        var person = PortraitLabPerson.riedel {
            didSet { load() }
        }
        private(set) var scene: Result<PortraitScene, PortraitLabError> = .failure(.noRig)
        private(set) var canvasMixer: PortraitMixer?
        private(set) var metalMixer: PortraitMixer?
        private(set) var stageMixers: [PortraitMixer] = []

        init(store: PortraitStore = PortraitStore()) {
            self.store = store
            renderer = MetalPortraitRenderer.shared()
            load()
        }

        var metal: MetalPortraitRenderer? { try? renderer.get() }

        func load() {
            scene = Self.scene(store.library, person.slug, person.party)
            guard case .success(let scene) = scene else {
                canvasMixer = nil
                metalMixer = nil
                stageMixers = []
                return
            }
            canvasMixer = PortraitMixer(scene: scene)
            metalMixer = PortraitMixer(scene: scene)
            stageMixers = (0..<PortraitBenchmark.portraits).map { _ in PortraitMixer(scene: scene) }
        }

        func pulseStage() {
            let now = PortraitClock.now
            for mixer in stageMixers { mixer.apply(.tap, at: now) }
        }

        func follow(roll: Double) {
            let now = PortraitClock.now
            for mixer in [canvasMixer, metalMixer].compactMap({ $0 }) {
                mixer.apply(.tilt(roll), at: now)
            }
        }

        static func scene(_ library: PortraitLibrary, _ slug: String, _ party: String)
            -> Result<PortraitScene, PortraitLabError>
        {
            guard let data = library.rig, let rig = PortraitRig(data: data) else {
                return .failure(.noRig)
            }
            let traits = library.traits(for: slug) ?? rig.neutral(slug: slug, party: party)
            guard let document = rig.document(for: traits, party: party) else {
                return .failure(.noRig)
            }
            do {
                return .success(try PortraitScene(document: document))
            } catch PortraitSceneError.unsupported(let feature) {
                return .failure(.unsupported(feature))
            } catch {
                return .failure(.unsupported(String(describing: error)))
            }
        }
    }

    public struct PortraitLabScreen: View {
        static let side: CGFloat = 120
        static let gestures: [PortraitGesture] = [.lookAround, .tilt, .browRaise]

        public init() {}

        public var body: some View {
            ModelHost(PortraitLabModel()) { PortraitLabPage() }
        }
    }

    private struct PortraitLabPage: View {
        @Environment(PortraitLabModel.self) private var model
        @ReducesMotion private var reduceMotion
        @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
        @Environment(\.liteMode) private var liteMode

        private var isAnimated: Bool { !reduceMotion && !MotionBudget.isConstrained }

        var body: some View {
            @Bindable var model = model
            Form {
                Section {
                    Picker(selection: $model.person) {
                        ForEach(PortraitLabPerson.allCases) { person in
                            Text(verbatim: person.name).tag(person)
                        }
                    } label: {
                        Text(verbatim: "Pessoa")
                    }
                    content
                } header: {
                    Text(verbatim: "Três motores").sectionTitle()
                } footer: {
                    Text(verbatim: footer)
                }
                PortraitLabMeasureSection(model: model)
            }
            .navigationTitle(Text(verbatim: "Bonequinhos em Metal"))
            .onAppear { if isAnimated { model.tilt.start() } }
            .onDisappear { model.tilt.stop() }
            .onChange(of: model.tilt.roll) { _, roll in model.follow(roll: roll) }
            .onChange(of: model.benchmark.pulse) { model.pulseStage() }
        }

        @ViewBuilder private var content: some View {
            switch model.scene {
            case .failure(.noRig):
                Text(verbatim: "Sem rig de retrato neste build")
            case .failure(.unsupported(let feature)):
                Text(verbatim: "Rig fora do subconjunto: \(feature)")
            case .success:
                if let stage = model.benchmark.stage {
                    PortraitLabStage(model: model, engine: stage)
                } else {
                    HStack(alignment: .top, spacing: .spaceS) {
                        ForEach(PortraitEngine.allCases) { engine in
                            VStack(spacing: .spaceXS) {
                                portrait(engine)
                                    .aspectRatio(1, contentMode: .fit)
                                    .frame(maxWidth: PortraitLabScreen.side)
                                    .clipShape(.circle)
                                    .accessibilityElement(children: .combine)
                                    .accessibilityLabel(
                                        Text(
                                            verbatim:
                                                "Ilustração de \(model.person.name), motor \(engine.rawValue)"
                                        )
                                    )
                                    .accessibilityAddTraits(.isImage)
                                Text(verbatim: engine.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }

        @ViewBuilder private func portrait(_ engine: PortraitEngine) -> some View {
            switch engine {
            case .lottie:
                PortraitArtView(
                    store: model.store,
                    request: PortraitRequest(
                        slug: model.person.slug, party: model.person.party, isStill: !isAnimated))
            case .canvas:
                if let mixer = model.canvasMixer {
                    CanvasPortraitView(mixer: mixer, isAnimated: isAnimated)
                        .id(model.person)
                }
            case .metal:
                switch model.renderer {
                case .success(let renderer):
                    if let mixer = model.metalMixer {
                        MetalPortraitView(mixer: mixer, renderer: renderer, isAnimated: isAnimated)
                            .id(model.person)
                    }
                case .failure:
                    Text(verbatim: "Metal indisponível neste aparelho")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
            }
        }

        private var footer: String {
            if !isAnimated { return "Movimento reduzido: só imagem parada. \(constraint)" }
            return
                "FSC-025: toque para reagir, segure para pensar, arraste para o olhar seguir e incline o iPhone. Lottie não tem essas ações. Só em builds de desenvolvimento. \(tiltReading)"
        }

        private var constraint: String {
            let info = ProcessInfo.processInfo
            var reasons: [String] = []
            if systemReduceMotion { reasons.append("Reduzir movimento ligado") }
            if liteMode.reducesMotion && !systemReduceMotion { reasons.append("modo leve") }
            if info.isLowPowerModeEnabled { reasons.append("Modo Pouca Energia") }
            if info.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue {
                reasons.append("aparelho quente")
            }
            return "Motivo: \(reasons.joined(separator: ", "))."
        }

        private var tiltReading: String {
            guard model.tilt.isLive else { return "Sensor de inclinação desligado." }
            let read = model.tilt.roll.formatted(.number.precision(.fractionLength(1)))
            let limit = (model.canvasMixer?.limits.roll ?? 0).formatted(
                .number.precision(.fractionLength(1)))
            return "Inclinação lida: \(read)°, aplicada até \(limit)°."
        }
    }

    private struct PortraitLabStage: View {
        let model: PortraitLabModel
        let engine: PortraitEngine

        var body: some View {
            VStack(spacing: .spaceS) {
                Text(
                    verbatim:
                        "Medindo \(engine.rawValue), rodada \(model.benchmark.round) de \(PortraitBenchmark.rounds)"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                HStack(spacing: .spaceS) {
                    ForEach(Array(model.stageMixers.enumerated()), id: \.offset) { index, mixer in
                        stagePortrait(mixer, index)
                            .aspectRatio(1, contentMode: .fit)
                            .frame(maxWidth: PortraitLabScreen.side)
                            .clipShape(.circle)
                            .accessibilityHidden(true)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }

        @ViewBuilder private func stagePortrait(_ mixer: PortraitMixer, _ index: Int) -> some View {
            switch engine {
            case .lottie:
                let gestures = PortraitLabScreen.gestures
                PortraitArtView(
                    store: model.store,
                    request: PortraitRequest(
                        slug: model.person.slug, party: model.person.party, isStill: false,
                        gesture: gestures[(model.benchmark.pulse + index) % gestures.count]))
            case .canvas:
                CanvasPortraitView(mixer: mixer, isAnimated: true)
            case .metal:
                if let renderer = model.metal {
                    MetalPortraitView(mixer: mixer, renderer: renderer, isAnimated: true)
                }
            }
        }
    }

    private struct PortraitLabMeasureSection: View {
        let model: PortraitLabModel

        var body: some View {
            Section {
                Button {
                    Task { await model.benchmark.run(renderer: model.metal) }
                } label: {
                    HStack(spacing: .spaceS) {
                        Text(verbatim: "Medir")
                        if model.benchmark.isRunning { ProgressView() }
                    }
                }
                .disabled(model.benchmark.isRunning)
                ForEach(model.benchmark.results) { measure in
                    VStack(alignment: .leading, spacing: .space2XS) {
                        Text(verbatim: measure.engine.rawValue).font(.headline)
                        Text(verbatim: Self.summary(measure))
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            } header: {
                Text(verbatim: "Medição").sectionTitle()
            } footer: {
                Text(
                    verbatim:
                        "Cada motor roda sozinho por 20 s com 3 bonequinhos de até 120 pt, três vezes, com 5 s de pausa; a tabela mostra a mediana. GPU só no Metal, somando os 3 bonequinhos. \(Self.preparation(model.metal))"
                )
            }
        }

        static func preparation(_ renderer: MetalPortraitRenderer?) -> String {
            guard let renderer else { return "Metal indisponível neste aparelho." }
            let milliseconds =
                Double(renderer.preparation.components.attoseconds) / 1e15
                + Double(renderer.preparation.components.seconds) * 1_000
            let text = milliseconds.formatted(.number.precision(.fractionLength(1)))
            return "Pipeline do Metal pronto em \(text) ms."
        }

        static func summary(_ measure: PortraitMeasure) -> String {
            let one = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(1))
            let two = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(2))
            var parts = [
                "CPU \(measure.cpuPercent.formatted(one))%",
                "memória +\(measure.memoryMegabytes.formatted(one)) MB",
                "perdidos \(measure.droppedPercent.formatted(one))%",
            ]
            if let average = measure.gpuAverage, let tail = measure.gpuP95 {
                parts.append("GPU \(average.formatted(two)) ms, p95 \(tail.formatted(two)) ms")
            }
            parts.append("temperatura \(thermal(measure.thermal))")
            return parts.joined(separator: " · ")
        }

        private static func thermal(_ state: ProcessInfo.ThermalState) -> String {
            switch state {
            case .nominal: "normal"
            case .fair: "morna"
            case .serious: "quente"
            case .critical: "crítica"
            @unknown default: "—"
            }
        }
    }

    public struct PortraitLabLaunch: ViewModifier {
        static let key = "portraitLab"
        @State private var isPresented = UserDefaults.standard.bool(forKey: PortraitLabLaunch.key)

        public init() {}

        public func body(content: Content) -> some View {
            #if os(macOS)
                content.sheet(isPresented: $isPresented) {
                    NavigationStack { PortraitLabScreen() }
                }
            #else
                content.fullScreenCover(isPresented: $isPresented) {
                    NavigationStack { PortraitLabScreen() }
                }
            #endif
        }
    }
#endif
