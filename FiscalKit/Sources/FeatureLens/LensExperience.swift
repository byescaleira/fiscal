import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import FiscalResource
import SwiftUI

extension View {
    public func lensExperience(isReady: Bool) -> some View {
        modifier(LensExperience(isReady: isReady))
    }
}

private struct LensExperience: ViewModifier {
    @Environment(LensContext.self) private var context
    @Environment(SessionModel.self) private var session
    @Environment(\.appTint) private var inheritedTint
    let isReady: Bool

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .top, spacing: .zero) {
                if let stance = context.preview?.stance {
                    LensPreviewBanner(stance: stance)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.smooth, value: context.isPreviewing)
            .appTint(LensPaletteSwatch.named(context.active?.palette)?.accent ?? inheritedTint)
            .task { await context.load() }
            .onChange(of: context.saved) { session.reload() }
            .modifier(LensSetupPresentation(isPresented: isReady && context.needsSetup))
    }
}

private struct LensSetupPresentation: ViewModifier {
    let isPresented: Bool
    @State private var isShown = false

    func body(content: Content) -> some View {
        presenting(content)
            .task(id: isPresented) {
                guard isPresented else {
                    isShown = false
                    return
                }
                try? await Task.sleep(for: .milliseconds(450))
                if !Task.isCancelled { isShown = true }
            }
    }

    @ViewBuilder
    private func presenting(_ content: Content) -> some View {
        #if os(macOS)
            content.sheet(isPresented: $isShown) {
                LensSetupHost()
                    .frame(minWidth: .readableColumn, minHeight: .readableColumn)
                    .interactiveDismissDisabled()
            }
        #else
            content.fullScreenCover(isPresented: $isShown) { LensSetupHost() }
        #endif
    }
}

private struct LensSetupHost: View {
    @Environment(LensContext.self) private var context

    var body: some View {
        ModelHost(LensSetupModel(context: context, catalog: try? ArtCatalog.bundled())) {
            LensSetupScreen()
        }
    }
}

private struct LensPreviewBanner: View {
    @Environment(LensContext.self) private var context
    let stance: PoliticalStance

    var body: some View {
        AdaptiveRow(spacing: .spaceM) {
            VStack(alignment: .leading, spacing: .space2XS) {
                LensBadge(stance)
                Text("Another lens for a moment. Nothing is saved.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: .zero)
            Button("Back to Mine", systemImage: "arrow.uturn.backward") { context.endPreview() }
                .prominentButton()
        }
        .padding(.horizontal, .spaceL)
        .padding(.vertical, .spaceS)
        .surface(in: .rect(cornerRadius: .radiusL))
        .padding(.horizontal, .spaceL)
        .padding(.bottom, .spaceS)
        .accessibilityElement(children: .contain)
    }
}
