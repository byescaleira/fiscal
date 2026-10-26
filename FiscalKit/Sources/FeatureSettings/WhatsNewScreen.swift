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
                    ReleaseCard(release: release, isCurrent: true)
                }
                ForEach(settings.earlierReleases) { ReleaseCard(release: $0, isCurrent: false) }
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

private struct ReleaseCard: View {
    @Environment(\.appTint) private var appTint
    let release: Release
    let isCurrent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceL) {
            ReleaseCardHeader(release: release, isCurrent: isCurrent)
            Divider()
            VStack(alignment: .leading, spacing: .spaceL) {
                ForEach(Array(release.notes.enumerated()), id: \.element.id) { index, note in
                    ReleaseNoteRow(note: note)
                        .releaseCascade(isCurrent ? index + 1 : 0)
                }
            }
        }
        .padding(.spaceL)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.groupedRow, in: .rect(cornerRadius: .radiusGroup, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: .radiusGroup, style: .continuous)
                .strokeBorder(
                    isCurrent ? appTint.opacity(.opacitySoft) : .clear,
                    lineWidth: .selectionStroke)
        }
    }
}

private struct ReleaseCardHeader: View {
    @Environment(\.appTint) private var appTint
    let release: Release
    let isCurrent: Bool

    var body: some View {
        HStack(alignment: .top, spacing: .spaceM) {
            VStack(alignment: .leading, spacing: .space2XS) {
                Group {
                    if isCurrent {
                        Chip("Current Version", color: appTint, shape: .capsule)
                    } else {
                        Chip("Earlier Version", color: .secondary, shape: .capsule)
                    }
                }
                .textCase(.uppercase)
                Text(verbatim: release.version)
                    .font(.scoreboardNumber)
                    .monospacedDigit()
                    .padding(.top, .space2XS)
                Text(verbatim: release.headline)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: .zero)
            if isCurrent {
                HStack(spacing: -.spaceS) {
                    ForEach(Array(release.heroNotes.prefix(3).enumerated()), id: \.element.id) {
                        index, note in
                        SymbolBadge(
                            note.symbol, color: note.color.color, size: .badgeM, style: .filled
                        )
                        .overlay(Circle().stroke(Color.groupedRow, lineWidth: .selectionStroke))
                        .releaseCascade(index)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: "\(release.title). \(release.headline)"))
    }
}

private struct ReleaseNoteRow: View {
    let note: ReleaseNote

    var body: some View {
        HStack(alignment: .top, spacing: .spaceM) {
            SymbolBadge(note.symbol, color: note.color.color, size: .badgeL, style: .filled)
            VStack(alignment: .leading, spacing: .space2XS) {
                Text(verbatim: note.title).font(.rowTitle)
                Text(verbatim: note.detail).font(.rowDetail).foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: .zero)
        }
        .accessibilityElement(children: .combine)
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
            .animation(reduceMotion ? nil : .bouncy.delay(Double(index) * 0.04), value: isShown)
            .task { isShown = true }
    }
}
