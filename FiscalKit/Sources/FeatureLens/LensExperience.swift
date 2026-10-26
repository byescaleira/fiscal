import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import FiscalResource
import SwiftUI

extension View {
    public func lensExperience(isReady: Bool, service: (any PublicDataService)?) -> some View {
        modifier(LensExperience(isReady: isReady, service: service))
    }
}

private struct LensExperience: ViewModifier {
    @Environment(LensContext.self) private var context
    @Environment(SessionModel.self) private var session
    @Environment(\.appTint) private var inheritedTint
    let isReady: Bool
    let service: (any PublicDataService)?

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .top, spacing: .zero) {
                if let preview = context.preview {
                    LensPreviewBanner(lens: preview)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.smooth, value: context.isPreviewing)
            .appTint(LensPaletteSwatch.named(context.active?.palette)?.accent ?? inheritedTint)
            .task { await context.load() }
            .onChange(of: context.saved) { session.reload() }
            .modifier(
                LensSetupPresentation(
                    isPresented: isReady && context.needsSetup, service: service,
                    follows: session.repositories.follows))
    }
}

private struct LensSetupPresentation: ViewModifier {
    let isPresented: Bool
    let service: (any PublicDataService)?
    let follows: any FollowRepository
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
                LensSetupHost(service: service, follows: follows)
                    .frame(minWidth: .readableColumn, minHeight: .readableColumn)
                    .interactiveDismissDisabled()
            }
        #else
            content.fullScreenCover(isPresented: $isShown) { LensSetupHost(service: service, follows: follows) }
        #endif
    }
}

private struct LensSetupHost: View {
    @Environment(LensContext.self) private var context
    let service: (any PublicDataService)?
    let follows: any FollowRepository

    var body: some View {
        ModelHost(
            LensSetupModel(
                context: context, catalog: try? ArtCatalog.bundled(),
                icons: SystemAppIconSwitcher(), service: service, follows: follows)
        ) {
            LensSetupScreen()
        }
    }
}

private struct LensPreviewBanner: View {
    @Environment(LensContext.self) private var context
    @Environment(\.appTint) private var tint
    let lens: Lens

    var body: some View {
        AdaptiveRow(spacing: .spaceM) {
            VStack(alignment: .leading, spacing: .space2XS) {
                Label("Another lens", systemImage: "eye")
                    .font(.chipLabel)
                    .foregroundStyle(tint)
                Text(
                    lens.isNeutral
                        ? LocalizedStringKey("Neutral order for a moment. Nothing is saved.")
                        : "What stands out for those who support someone else. Nothing is saved."
                )
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
