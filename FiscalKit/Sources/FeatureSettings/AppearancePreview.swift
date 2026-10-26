import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct AppearancePreviewSection: View {
    var body: some View {
        Section {
            AppearancePreview()
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
        }
    }
}

struct AppearancePreview: View {
    @Environment(SettingsModel.self) private var settings

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceM) {
            HStack(spacing: .spaceS) {
                Text("Preview")
                    .font(.chipLabel)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                Spacer(minLength: .zero)
                Text(verbatim: "\(settings.appearance.title) · \(settings.tintName)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .contentTransition(.opacity)
            }
            PreviewTodayCard()
            PreviewControls()
        }
        .padding(.spaceL)
        .background(.groupedBackground, in: .rect(cornerRadius: .radiusGroup))
        .overlay {
            RoundedRectangle(cornerRadius: .radiusGroup, style: .continuous)
                .strokeBorder(.separator, lineWidth: .spaceHairline / 2)
        }
        .partyMarksStill()
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
        .animation(.smooth, value: settings.tint)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Preview of the look"))
        .accessibilityValue(Text(verbatim: "\(settings.appearance.title), \(settings.tintName)"))
    }
}

private struct PreviewTodayCard: View {
    @Environment(\.appTint) private var tint

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            HStack(spacing: .spaceS) {
                Label {
                    Text(verbatim: Theme.health.title.uppercased())
                } icon: {
                    Image(systemName: Theme.health.symbol)
                }
                .font(.caption2.weight(.heavy))
                .foregroundStyle(tint)
                .lineLimit(1)
                Spacer(minLength: .zero)
                Text("Highlight of the Moment")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text("Plenary approves the bill that takes vaccination to public schools")
                .font(.headline)
                .lineLimit(2)
            HStack(alignment: .lastTextBaseline, spacing: .spaceL) {
                PreviewCount(label: "Yes", value: 312, symbol: "checkmark", color: .voteYes)
                PreviewCount(label: "No", value: 141, symbol: "xmark", color: .voteNo)
                Spacer(minLength: .zero)
                Label("Approved", systemImage: "checkmark.seal")
                    .font(.chipLabel)
                    .foregroundStyle(Color.voteYes)
                    .padding(.horizontal, .spaceS)
                    .padding(.vertical, .space2XS)
                    .background(Color.voteYes.opacity(.opacityTint), in: .capsule)
            }
            TallyBar(segments: [
                TallyBar.Segment(id: "yes", value: 312, color: .voteYes),
                TallyBar.Segment(id: "no", value: 141, color: .voteNo),
                TallyBar.Segment(id: "others", value: 12, color: .voteAbstain),
            ])
            HStack(spacing: .spaceXS) {
                ForEach(["MDB", "PL", "PT"], id: \.self) { PartyMark($0) }
                Spacer(minLength: .zero)
                Text("Party colors never change")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(.spaceL)
        .background(.groupedRow, in: .rect(cornerRadius: .radiusL))
    }
}

private struct PreviewCount: View {
    let label: LocalizedStringKey
    let value: Int
    let symbol: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceHairline) {
            Label(label, systemImage: symbol)
                .font(.caption2.weight(.heavy))
                .textCase(.uppercase)
                .foregroundStyle(color)
            Text(verbatim: PublicFormat.number(value))
                .font(.scoreboardNumber)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }
}

private struct PreviewControls: View {
    @Environment(\.appTint) private var tint

    var body: some View {
        HStack(spacing: .spaceM) {
            Label("Follow", systemImage: "plus")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, .spaceL)
                .padding(.vertical, .spaceS)
                .background(tint, in: .capsule)
            Spacer(minLength: .zero)
            HStack(spacing: .spaceM) {
                ForEach(AppSection.allCases) { section in
                    Image(systemName: section.systemImage)
                        .foregroundStyle(section == .today ? tint : Color.secondary)
                }
            }
            .font(.icon(.s))
            .padding(.horizontal, .spaceM)
            .padding(.vertical, .spaceS)
            .background(.groupedRow, in: .capsule)
        }
    }
}
