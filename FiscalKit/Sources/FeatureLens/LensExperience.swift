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
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.liteMode) private var liteMode
    @Environment(\.appTint) private var inheritedTint
    let isReady: Bool

    func body(content: Content) -> some View {
        let reduceMotion = systemReduceMotion || liteMode.reducesMotion
        content
            .safeAreaInset(edge: .top, spacing: .zero) {
                if let preview = context.preview {
                    LensPreviewBanner(lens: preview)
                        .transition(
                            reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? nil : .smooth, value: context.isPreviewing)
            .appTint(LensPaletteSwatch.named(context.active?.palette)?.accent ?? inheritedTint)
            .task { await context.load() }
            .onChange(of: context.saved) { session.reload() }
            .modifier(LensSetupPresentation(isPresented: isReady && context.needsSetup))
    }
}

private struct LensSetupPresentation: ViewModifier {
    @Environment(FiscalNavigation.self) private var navigation
    let isPresented: Bool

    func body(content: Content) -> some View {
        content
            .task(id: isPresented) {
                guard isPresented else {
                    navigation.isShowingLensSetup = false
                    return
                }
                try? await Task.sleep(for: .milliseconds(450))
                if !Task.isCancelled { navigation.isShowingLensSetup = true }
            }
    }
}

public struct LensSetupFlow: View {
    @Environment(LensContext.self) private var context
    private let service: (any PublicDataService)?
    private let follows: any FollowRepository

    public init(service: (any PublicDataService)?, follows: any FollowRepository) {
        self.service = service
        self.follows = follows
    }

    public var body: some View {
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
                .controlSize(.large)
        }
        .padding(.horizontal, .spaceL)
        .padding(.vertical, .spaceS)
        .surface(in: .rect(cornerRadius: .radiusL))
        .padding(.horizontal, .spaceL)
        .padding(.bottom, .spaceS)
        .accessibilityElement(children: .contain)
    }
}
