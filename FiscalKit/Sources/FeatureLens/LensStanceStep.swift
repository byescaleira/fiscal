import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct LensWelcomeStep: View {
    @Environment(LensSetupModel.self) private var setup

    var body: some View {
        VStack(spacing: .spaceXL) {
            PosterCarousel(works: setup.welcomeWorks)
                .padding(.horizontal, -.spaceInset)
            VStack(spacing: .spaceM) {
                Text("Welcome to Fiscal")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("What your representatives do with your vote")
                    .font(.largeTitle.weight(.black))
                    .accessibilityAddTraits(.isHeader)
                Text("The same facts for everyone, in the order that matters to you.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct LensStanceStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: .spaceXL) {
            LensStepHeader(
                "Which side are you on?",
                message: Text(
                    "Fiscal adapts what comes first, the colors, the art and the highlights. The numbers are the same for everyone."
                ))
            LensSpectrumCard()
            LensNeutralChoices()
            LensEffectCard()
            LensPrivacyCard()
        }
    }
}

struct LensPrivacyCard: View {
    @Environment(\.appTint) private var tint

    var body: some View {
        HStack(alignment: .top, spacing: .spaceM) {
            Image(systemName: "lock.fill")
                .font(.icon(.m, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: .badgeL, height: .badgeL)
                .background(tint.opacity(.opacityTint), in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: .spaceXS) {
                Text("Only on this iPhone").font(.headline)
                Text(
                    "Your choice stays only on this iPhone. It does not go to any server, it is not in iCloud or in backups, it is not shared and Fiscal does not know what it is."
                )
                .font(.subheadline)
                Text("A new iPhone or a reinstall asks for it again.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.spaceL)
        .background(Color.primary.opacity(.opacityFill), in: .rect(cornerRadius: .radiusL))
        .accessibilityElement(children: .combine)
    }
}
