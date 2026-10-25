import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct WhatsNewScreen: View {
    @Environment(SettingsModel.self) private var settings

    var body: some View {
        ScrollView {
            VStack(spacing: .spaceXL) {
                if let release = settings.featuredRelease {
                    WhatsNewHero(release: release)
                    WhatsNewNotes(notes: release.notes)
                }
                ForEach(settings.earlierReleases) { EarlierRelease(release: $0) }
            }
            .padding(.horizontal, .spaceInset)
            .padding(.top, .spaceS)
            .padding(.bottom, .spaceXL)
        }
        .readableWidth()
        .background(.groupedBackground)
        .fontDesign(.rounded)
        #if os(visionOS) || os(tvOS)
            .navigationTitle(String(appLocalized: "What's New in Version \(settings.info.number)"))
        #else
            .navigationTitle("What's New")
            .navigationSubtitle(String(appLocalized: "Version \(settings.info.number)"))
        #endif
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

private struct WhatsNewHero: View {
    @Environment(\.appTint) private var appTint
    let release: Release

    var body: some View {
        VStack(spacing: .spaceM) {
            HStack(spacing: -.spaceS) {
                ForEach(Array(release.heroNotes.enumerated()), id: \.element.id) { index, note in
                    SymbolBadge(note.symbol, color: note.color.color, size: .badgeL, style: .filled)
                        .overlay(Circle().stroke(Color.groupedBackground, lineWidth: 3))
                        .releaseCascade(index)
                }
            }
            .padding(.vertical, .spaceS)
            Chip("Current Version", color: appTint, shape: .capsule).textCase(.uppercase)
            VStack(spacing: .spaceXS) {
                Text(verbatim: release.title).font(.titleLarge)
                Text(verbatim: release.headline).font(.body).foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

private struct WhatsNewNotes: View {
    let notes: [ReleaseNote]

    var body: some View {
        VStack(spacing: .spaceS) {
            ForEach(Array(notes.enumerated()), id: \.element.id) { index, note in
                ReleaseNoteCard(note: note).releaseCascade(index + 2)
            }
        }
    }
}

private struct ReleaseNoteCard: View {
    let note: ReleaseNote

    var body: some View {
        HStack(alignment: .top, spacing: .spaceM) {
            SymbolBadge(note.symbol, color: note.color.color, size: .badgeL, style: .filled)
            VStack(alignment: .leading, spacing: .space2XS) {
                Text(verbatim: note.title).font(.rowTitle)
                Text(verbatim: note.detail).font(.rowDetail).foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.spaceL)
        .background(.groupedRow, in: .rect(cornerRadius: .radiusL))
        .accessibilityElement(children: .combine)
    }
}

private struct EarlierRelease: View {
    let release: Release

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            Text(verbatim: release.title).font(.headline).padding(.horizontal, .spaceS)
            VStack(alignment: .leading, spacing: .spaceM) {
                ForEach(release.notes) { note in
                    IconRow(
                        verbatim: note.title, detail: note.detail, symbol: note.symbol,
                        color: note.color.color)
                }
            }
            .padding(.spaceL)
            .background(.groupedRow, in: .rect(cornerRadius: .radiusL))
        }
    }
}

extension View {
    fileprivate func releaseCascade(_ index: Int) -> some View {
        modifier(ReleaseCascade(index: index))
    }
}

private struct ReleaseCascade: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShown = false
    let index: Int

    func body(content: Content) -> some View {
        content
            .opacity(isShown || reduceMotion ? 1 : 0)
            .scaleEffect(isShown || reduceMotion ? 1 : 0.8)
            .animation(reduceMotion ? nil : .bouncy.delay(Double(index) * 0.05), value: isShown)
            .task { isShown = true }
    }
}
