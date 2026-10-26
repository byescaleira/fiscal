import FeatureCore
import FiscalDesignSystem
import SwiftUI

struct AboutScreen: View {
    var body: some View {
        ModelHost(AboutModel()) { AboutPage() }
    }
}

private struct AboutPage: View {
    var body: some View {
        SettingsPage("About Fiscal") {
            AboutHeroSection()
            AboutValuesSection()
            #if !os(tvOS)
                AboutShareSection()
            #endif
            AboutLinksSection()
            AboutCreditsSection()
        }
    }
}

private struct AboutHeroSection: View {
    @Environment(SettingsModel.self) private var settings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appTint) private var appTint
    @State private var isShown = false

    var body: some View {
        Section {
            EmptyView()
        } header: {
            VStack(spacing: .spaceM) {
                AppIconImage(icon: settings.appIcon, size: .medallion)
                    .shadow(color: .black.opacity(.opacityTint), radius: .spaceM, y: .space2XS)
                    .scaleEffect(isShown || reduceMotion ? 1 : 0.7)
                    .opacity(isShown || reduceMotion ? 1 : 0)
                Chip(
                    "Version \(settings.info.version)", color: appTint, shape: .capsule
                )
                .monospacedDigit()
                VStack(spacing: .space2XS) {
                    Text(verbatim: "Fiscal").font(.amountHero).foregroundStyle(.primary)
                    Text("What your representatives do with your vote, from official sources.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, .spaceL)
            .textCase(nil)
            .animation(reduceMotion ? nil : .bouncy, value: isShown)
            .accessibilityElement(children: .combine)
            .task { isShown = true }
        }
    }
}
