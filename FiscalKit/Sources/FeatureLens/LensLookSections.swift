import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import FiscalResource
import SwiftUI

struct LensThemesSection: View {
    @Environment(LensModel.self) private var lens

    var body: some View {
        Section {
            if let tally = lens.tally, lens.showsChart {
                LensThemeBars(tally: tally)
                if let slice = lens.focusedSlice {
                    Text(verbatim: lens.focusTitle(for: slice))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(lens.focusedVotes) { vote in
                        LensFocusedVoteRow(vote: vote)
                    }
                }
            } else {
                if lens.tally != nil {
                    IconRow(
                        "No votes on these topics in the latest update.", symbol: "tray",
                        color: .secondary)
                }
                ForEach(Array(lens.themes.enumerated()), id: \.element) { index, theme in
                    LensThemeOrderRow(theme: theme, index: index)
                }
                .onMove { source, destination in
                    Task { await lens.moveThemes(from: source, to: destination) }
                }
            }
            Button("Change Topics", systemImage: "list.number") { lens.edit(.themes) }
        } header: {
            Text("Your topics").sectionTitle()
        } footer: {
            if lens.showsChart {
                Text(
                    "Ordered by how often each topic shows up in the latest votes of the Chamber and the Senate. Tap a topic to see its votes."
                )
            } else {
                Text(
                    "These topics come first in Today, Votes and Money, in this order. Drag, or touch and hold to move or remove. Nothing is hidden."
                )
            }
        }
    }
}
