import FeatureCore
import FiscalDesignSystem
import SwiftUI

#if DEBUG
    struct MetalLabScreen: View {
        var body: some View {
            Form {
                Section {
                    MetalLabRow(
                        title: "Curtir", detail: "Onda a partir do toque e partículas no coração",
                        symbol: "heart", color: .retroRust
                    ) { LikePrototype() }
                    MetalLabRow(
                        title: "Papel no cartão",
                        detail: "Grão e luz no cartão de compartilhar e o teste da exportação",
                        symbol: "doc.richtext", color: .retroMustard
                    ) { PaperPrototype() }
                    MetalLabRow(
                        title: "Brilho na inclinação",
                        detail: "Luz que segue o iPhone no cartão do político",
                        symbol: "sparkles", color: .retroDenim
                    ) { SheenPrototype() }
                    MetalLabRow(
                        title: "Carta colecionável",
                        detail: "Moldura metalizada, brilhos e a carta girando com o iPhone",
                        symbol: "rectangle.portrait.on.rectangle.portrait", color: .retroRust
                    ) { CollectiblePrototype() }
                } header: {
                    Text(verbatim: "Protótipos").sectionTitle()
                } footer: {
                    Text(
                        verbatim:
                            "FSC-023: protótipos só em builds de desenvolvimento, para escolher o que vira mudança. Nenhum efeito muda o dado: cor, ordem e tamanho continuam sendo os números reais."
                    )
                }
            }
            .task { await MetalLab.compile() }
            .navigationTitle(Text(verbatim: "Metal"))
        }
    }

    private struct MetalLabRow<Destination: View>: View {
        let title: String
        let detail: String
        let symbol: String
        let color: Color
        @ViewBuilder let destination: () -> Destination

        var body: some View {
            NavigationLink(destination: destination) {
                Label {
                    VStack(alignment: .leading, spacing: .space2XS) {
                        Text(verbatim: title)
                        Text(verbatim: detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: symbol)
                        .foregroundStyle(color)
                }
            }
        }
    }
#endif

public struct MetalLabLaunch: ViewModifier {
    @State private var prototype = MetalLabLaunch.requested

    public init() {}

    public func body(content: Content) -> some View {
        #if DEBUG && !os(macOS)
            content.fullScreenCover(item: $prototype) { prototype in
                NavigationStack { prototype.screen }
            }
        #else
            content
        #endif
    }

    private static var requested: MetalLabPrototype? {
        #if DEBUG
            UserDefaults.standard.string(forKey: "FiscalMetalLab").flatMap(
                MetalLabPrototype.init(rawValue:))
        #else
            nil
        #endif
    }
}

public enum MetalLabPrototype: String, Identifiable, Sendable {
    case lab, like, paper, sheen, collectible

    public var id: Self { self }

    #if DEBUG
        @MainActor @ViewBuilder var screen: some View {
            switch self {
            case .lab: MetalLabScreen()
            case .like: LikePrototype()
            case .paper: PaperPrototype()
            case .sheen: SheenPrototype()
            case .collectible: CollectiblePrototype()
            }
        }
    #endif
}
