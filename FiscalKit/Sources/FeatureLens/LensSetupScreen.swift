import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public struct LensSetupScreen: View {
    @Environment(LensSetupModel.self) private var setup
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appTint) private var inheritedTint
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        let tint = setup.palette?.accent ?? inheritedTint
        VStack(spacing: .zero) {
            LensSetupTopBar { dismiss() }
            ScrollView {
                LensSetupStepView(step: setup.step)
                    .id(setup.step)
                    .transition(stepTransition)
                    .padding(.horizontal, .spaceInset)
                    .padding(.bottom, .spaceXL)
                    .frame(maxWidth: .readableColumn)
                    .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            LensSetupActionBar()
        }
        .background { LensBackdrop(work: setup.backdrop) }
        .environment(\.colorScheme, .dark)
        .appTint(tint)
        .fontDesign(.rounded)
        .animation(reduceMotion ? nil : .smooth(duration: 0.45), value: setup.step)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.6), value: setup.backdrop)
        .sensoryFeedback(.selection, trigger: setup.draft)
        .task { await setup.loadPeople() }
        .onChange(of: setup.isFinished) { if setup.isFinished && setup.isEditing { dismiss() } }
    }

    private var stepTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .move(edge: setup.movesForward ? .trailing : .leading).combined(
                with: .opacity),
            removal: .move(edge: setup.movesForward ? .leading : .trailing).combined(
                with: .opacity))
    }
}

private struct LensSetupStepView: View {
    let step: LensSetupModel.Step

    var body: some View {
        switch step {
        case .welcome: LensWelcomeStep()
        case .support: LensSupportStep()
        case .themes: LensThemesStep()
        case .look: LensLookStep()
        }
    }
}

private struct LensSetupTopBar: View {
    @Environment(LensSetupModel.self) private var setup
    @Environment(\.appTint) private var tint
    let close: () -> Void

    var body: some View {
        HStack(spacing: .spaceM) {
            if setup.isEditing {
                Button("Cancel", systemImage: "xmark", action: close)
                    .labelStyle(.iconOnly)
                    .lensRoundButton()
            } else if setup.canGoBack {
                Button("Back", systemImage: "chevron.backward") { setup.goBack() }
                    .labelStyle(.iconOnly)
                    .lensRoundButton()
            }
            if setup.stepIndex > 0 && !setup.isEditing {
                ProgressBar(value: setup.progress, color: tint)
                    .animation(.smooth(duration: 1), value: setup.progress)
                Text(verbatim: setup.stepText)
                    .font(.chipLabel)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            } else {
                Spacer()
            }
        }
        .frame(minHeight: .badgeL)
        .padding(.horizontal, .spaceInset)
        .padding(.top, .spaceS)
    }
}

private struct LensSetupActionBar: View {
    @Environment(LensSetupModel.self) private var setup

    var body: some View {
        Button {
            Task { await setup.advance() }
        } label: {
            if setup.isSaving {
                ProgressView()
            } else {
                Text(verbatim: setup.primaryTitle)
            }
        }
        .primaryButton()
        .disabled(!setup.canContinue || setup.isSaving)
        .padding(.horizontal, .spaceInset)
        .padding(.vertical, .spaceM)
        .frame(maxWidth: .readableColumn)
    }
}

struct LensStepHeader: View {
    let title: LocalizedStringKey
    let message: Text?

    init(_ title: LocalizedStringKey, message: Text? = nil) {
        self.title = title
        self.message = message
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            Text(title)
                .font(.largeTitle.weight(.black))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let message {
                message
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, .spaceL)
    }
}

struct LensChoiceBackground: ViewModifier {
    @Environment(\.appTint) private var tint
    let isSelected: Bool

    func body(content: Content) -> some View {
        content
            .surface(
                tint: isSelected ? tint.opacity(.opacitySoft) : nil,
                in: .rect(cornerRadius: .radiusL), interactive: true
            )
            .overlay {
                RoundedRectangle(cornerRadius: .radiusL)
                    .strokeBorder(isSelected ? tint : .clear, lineWidth: .selectionStroke)
            }
    }
}

extension View {
    @ViewBuilder func lensRoundButton() -> some View {
        #if os(visionOS)
            buttonStyle(.bordered).buttonBorderShape(.circle)
        #else
            buttonStyle(.glass).buttonBorderShape(.circle)
        #endif
    }

    func lensChoice(isSelected: Bool) -> some View {
        modifier(LensChoiceBackground(isSelected: isSelected))
    }
}
