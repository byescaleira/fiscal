import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public struct LensScreen: View {
    @Environment(LensModel.self) private var lens

    public init() {}

    public var body: some View {
        @Bindable var lens = lens
        @Bindable var context = lens.context
        AdaptiveList {
            LensHeroSection()
            if lens.hasLens {
                LensSupportSection()
                LensThemesSection()
                LensLookSection()
                LensOtherSection()
            }
            LensPrivacySection()
        }
        .fontDesign(.rounded)
        .task { await lens.loadVotes() }
        .task(id: lens.supported) { await lens.loadSupport() }
        .navigationTitle("Lens")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(item: $lens.editing) { step in
            LensEditorHost(step: step).environment(lens)
        }
        .sheet(isPresented: $lens.isConfirmingErase) {
            LensEraseGuide().environment(lens)
        }
        .errorAlert($context.error)
    }
}

private struct LensEditorHost: View {
    @Environment(LensModel.self) private var lens
    let step: LensSetupModel.Step

    var body: some View {
        ModelHost(lens.editor(for: step)) { LensSetupScreen() }
            .presentationDetents([.large])
    }
}

private struct LensHeroSection: View {
    var body: some View {
        Section {
            LensHero()
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
        } footer: {
            Text(
                "Fiscal adapts the order, the highlights, the colors and the art. The facts are the same for everyone."
            )
        }
    }
}

private struct LensHero: View {
    @Environment(LensModel.self) private var lens
    @Environment(\.appTint) private var tint

    var body: some View {
        Color.clear
            .frame(height: .artBanner)
            .frame(maxWidth: .infinity)
            .background {
                if let work = lens.leadWork {
                    work.image.resizable().scaledToFill()
                } else {
                    LinearGradient(
                        colors: [tint, tint.opacity(.opacitySoft)], startPoint: .topLeading,
                        endPoint: .bottomTrailing)
                }
            }
            .overlay {
                LinearGradient(
                    colors: [.clear, .black.opacity(.opacityStrong)], startPoint: .top,
                    endPoint: .bottom)
            }
            .overlay(alignment: .bottomLeading) { LensHeroText() }
            .clipShape(.rect(cornerRadius: .radiusL))
            .accessibilityElement(children: .combine)
    }
}

private struct LensHeroText: View {
    @Environment(LensModel.self) private var lens

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            if lens.hasLens {
                LensBadge()
            }
            if !lens.supportedCards.isEmpty {
                LensFaces(cards: lens.supportedCards, size: .badgeL)
            }
            Text(verbatim: lens.heroTitle)
                .font(.titleMedium)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
                .contentTransition(.opacity)
            if let work = lens.leadWork {
                Text(verbatim: "\(work.artist) · \(work.caption) · \(work.licenseTitle)")
                    .font(.caption2)
                    .lineLimit(2)
            }
        }
        .foregroundStyle(.white)
        .padding(.spaceL)
    }
}

private struct LensEraseGuide: View {
    @Environment(LensModel.self) private var lens

    var body: some View {
        GuideSheet(
            index: 0, count: 1, isWorking: lens.isErasing,
            primary: GuideAction("Delete My Choice") { Task { await lens.erase() } },
            secondary: GuideAction("Keep My Lens") { lens.isConfirmingErase = false }
        ) {
            GuidePage(
                title: "Delete your lens?",
                message:
                    "Who you support, your topics and your look leave this iPhone for good. Then Fiscal asks for them again."
            ) {
                FiscalAnimationView(.privacy)
            }
        }
    }
}
