#if DEBUG
    import CoreGraphics
    import FeatureCore
    import FiscalDesignSystem
    import SwiftUI

    struct PaperPrototype: View {
        enum Variant: String, CaseIterable, Identifiable {
            case shader = "Shader"
            case texture = "Textura"
            case plain = "Hoje"
            var id: Self { self }
        }

        @State private var variant = Variant.shader
        @State private var export: PaperExport?
        @Environment(\.colorScheme) private var colorScheme

        var body: some View {
            Form {
                Section {
                    ChoicePills(
                        "Papel" as String, choices: Variant.allCases, selection: $variant,
                        label: \.rawValue)
                }
                Section {
                    VStack(alignment: .leading, spacing: .spaceL) {
                        PaperColumn(title: "Na tela") {
                            PaperCard(variant: variant)
                                .frame(width: PaperExport.width)
                        }
                        PaperColumn(title: "Exportado") {
                            if let export {
                                export.image
                                    .resizable()
                                    .aspectRatio(MetalLab.cardAspect, contentMode: .fit)
                                    .frame(width: PaperExport.width)
                            } else {
                                ProgressView()
                                    .frame(width: PaperExport.width)
                                    .aspectRatio(MetalLab.cardAspect, contentMode: .fit)
                            }
                        }
                    }
                    if let export {
                        Text(verbatim: export.summary)
                            .font(.footnote)
                            .monospacedDigit()
                    }
                } footer: {
                    Text(
                        verbatim:
                            "Embaixo, o mesmo cartão passado pelo ImageRenderer, como no compartilhar. A medida compara o ruído do fundo com o do cartão liso: se o grão aparece no número, o shader saiu na imagem. O texto fica fora do efeito, só o fundo ganha papel."
                    )
                }
            }
            .task(id: "\(variant.rawValue)-\(colorScheme)") {
                export = PaperExport.make(variant: variant, colorScheme: colorScheme)
            }
            .navigationTitle(Text(verbatim: "Papel no cartão"))
        }
    }

    private struct PaperColumn<Content: View>: View {
        let title: String
        @ViewBuilder let content: Content

        var body: some View {
            VStack(alignment: .leading, spacing: .spaceXS) {
                Text(verbatim: title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    struct PaperCard: View {
        let variant: PaperPrototype.Variant

        var body: some View {
            let vote = LabVote.chamber
            VStack(alignment: .leading, spacing: .spaceS) {
                Text(verbatim: "\(vote.house) · \(vote.date)")
                    .font(.caption2.weight(.semibold))
                    .textCase(.uppercase)
                Text(verbatim: vote.proposition)
                    .font(.emphasis(.title3, weight: .heavy))
                Spacer(minLength: .zero)
                Text(verbatim: "\(vote.yes) sim")
                    .font(.emphasis(.title, weight: .heavy))
                    .monospacedDigit()
                Text(verbatim: "\(vote.no) não")
                    .font(.emphasis(.title3, weight: .bold))
                    .monospacedDigit()
                Text(verbatim: "Precisava de \(vote.required). Não aprovado.")
                    .font(.caption2)
                Spacer(minLength: .zero)
                Text(verbatim: "Fiscal · Câmara dos Deputados")
                    .font(.caption2)
                    .opacity(.opacityStrong)
            }
            .foregroundStyle(Color.labInk)
            .padding(.spaceM)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .aspectRatio(MetalLab.cardAspect, contentMode: .fit)
            .background { PaperBackground(variant: variant) }
            .clipShape(.rect(cornerRadius: .radiusM))
        }
    }

    private struct PaperBackground: View {
        let variant: PaperPrototype.Variant

        var body: some View {
            switch variant {
            case .shader:
                Rectangle()
                    .fill(Color.retroCream)
                    .visualEffect { effect, proxy in
                        effect.colorEffect(
                            MetalLab.library.labPaper(
                                .float2(proxy.size), .float(Float(MetalLab.renderScale)),
                                .float(MetalLab.paperGrain), .float(MetalLab.paperFiber),
                                .float2(CGPoint(x: 0.2, y: 0.1))))
                    }
            case .texture:
                Rectangle()
                    .fill(Color.retroCream)
                    .overlay {
                        if let texture = PaperTexture.shared {
                            Image(decorative: texture, scale: MetalLab.renderScale)
                                .resizable(resizingMode: .tile)
                                .blendMode(.overlay)
                        }
                    }
            case .plain:
                Rectangle().fill(Color.retroCream)
            }
        }
    }

    extension Color {
        static let labInk = Color(light: 0x2B2118, dark: 0x2B2118)
    }

    enum PaperTexture {
        static let side = 256
        static let shared: CGImage? = make()

        private static func make() -> CGImage? {
            var generator = SeededGenerator(seed: 2026)
            let bytes = (0..<(side * side)).map { _ in
                UInt8.random(in: 112...144, using: &generator)
            }
            let provider = CGDataProvider(data: Data(bytes) as CFData)
            return provider.flatMap {
                CGImage(
                    width: side, height: side, bitsPerComponent: 8, bitsPerPixel: 8,
                    bytesPerRow: side,
                    space: CGColorSpaceCreateDeviceGray(),
                    bitmapInfo: CGBitmapInfo(rawValue: .zero),
                    provider: $0, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
            }
        }
    }

    struct SeededGenerator: RandomNumberGenerator {
        private var state: UInt64

        init(seed: UInt64) { state = seed }

        mutating func next() -> UInt64 {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return state
        }
    }

    struct PaperExport {
        let image: Image
        let spread: Double
        let plainSpread: Double
        let milliseconds: Double

        static let width: CGFloat = 300
        static let patch = 40

        var summary: String {
            let format = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(1))
            let carried = spread > plainSpread + 1
            return
                "Ruído do fundo: \(spread.formatted(format)) (liso: \(plainSpread.formatted(format))). \(carried ? "O efeito saiu na imagem." : "O efeito não saiu na imagem.") Render em \(milliseconds.formatted(format)) ms."
        }

        @MainActor
        static func make(variant: PaperPrototype.Variant, colorScheme: ColorScheme) -> PaperExport?
        {
            let clock = ContinuousClock()
            var rendered: CGImage?
            let duration = clock.measure { rendered = render(variant, colorScheme: colorScheme) }
            guard let rendered, let plain = render(.plain, colorScheme: colorScheme) else {
                return nil
            }
            let milliseconds =
                Double(duration.components.seconds) * MetalLab.millisecondsPerSecond
                + Double(duration.components.attoseconds) / 1e15
            return PaperExport(
                image: Image(decorative: rendered, scale: MetalLab.renderScale),
                spread: spreadOfCorner(rendered), plainSpread: spreadOfCorner(plain),
                milliseconds: milliseconds)
        }

        @MainActor
        private static func render(_ variant: PaperPrototype.Variant, colorScheme: ColorScheme)
            -> CGImage?
        {
            let renderer = ImageRenderer(
                content: PaperCard(variant: variant)
                    .frame(width: width)
                    .environment(\.colorScheme, colorScheme))
            renderer.scale = MetalLab.renderScale
            return renderer.cgImage
        }

        private static func spreadOfCorner(_ image: CGImage) -> Double {
            let side = patch
            var pixels = [UInt8](repeating: .zero, count: side * side * 4)
            let drawn: Bool = pixels.withUnsafeMutableBytes { buffer in
                guard
                    let context = CGContext(
                        data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8,
                        bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
                else { return false }
                let originX = image.width - side - image.width / 10
                let originY = image.height / 2 - side / 2
                context.draw(
                    image,
                    in: CGRect(
                        x: -originX, y: -(image.height - originY - side), width: image.width,
                        height: image.height))
                return true
            }
            guard drawn else { return .zero }
            let luminance = stride(from: 0, to: pixels.count, by: 4).map { index in
                (Double(pixels[index]) + Double(pixels[index + 1]) + Double(pixels[index + 2])) / 3
            }
            let mean = luminance.reduce(0, +) / Double(luminance.count)
            let variance =
                luminance.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(luminance.count)
            return variance.squareRoot()
        }
    }
#endif
