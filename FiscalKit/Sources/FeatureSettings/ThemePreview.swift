import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct ThemePreview: View {
    let appearance: Appearance

    var body: some View {
        Group {
            switch appearance {
            case .light: ThemeCanvas().environment(\.colorScheme, .light)
            case .dark: ThemeCanvas().environment(\.colorScheme, .dark)
            case .system:
                ZStack {
                    ThemeCanvas().environment(\.colorScheme, .light)
                    ThemeCanvas().environment(\.colorScheme, .dark)
                        .mask {
                            HStack(spacing: .zero) {
                                Color.clear
                                Color.black
                            }
                        }
                }
            }
        }
        .aspectRatio(CGSize.themeCanvas, contentMode: .fit)
        .clipShape(.rect(cornerRadius: .radiusM, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: .radiusM, style: .continuous)
                .stroke(.separator, lineWidth: .spaceHairline / 2)
        }
        .dynamicTypeSize(.large)
        .partyMarksStill()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct ThemeCanvas: View {
    var body: some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: .spaceM) {
                Text("Today").font(.titleLarge)
                ThemeCanvasLive()
                ThemeCanvasHighlight()
                Spacer(minLength: .zero)
                ThemeCanvasTabBar()
            }
            .padding(.spaceL)
            .foregroundStyle(.primary)
            .frame(width: .themeCanvasWidth, height: .themeCanvasHeight, alignment: .topLeading)
            .background(.groupedBackground)
            .scaleEffect(proxy.size.width / .themeCanvasWidth, anchor: .topLeading)
        }
    }
}

private struct ThemeCanvasLive: View {
    var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            Chip("Live", color: .negative, shape: .capsule).textCase(.uppercase)
            HStack(alignment: .lastTextBaseline) {
                Text(verbatim: "312").font(.scoreboardNumber).foregroundStyle(Color.voteYes)
                Spacer(minLength: .zero)
                Text(verbatim: "141").font(.scoreboardNumber).foregroundStyle(Color.voteNo)
            }
            .monospacedDigit()
            TallyBar(segments: [
                TallyBar.Segment(id: "yes", value: 312, color: .voteYes),
                TallyBar.Segment(id: "no", value: 141, color: .voteNo),
            ])
        }
        .padding(.spaceM)
        .background(.groupedRow, in: .rect(cornerRadius: .radiusM))
    }
}

private struct ThemeCanvasHighlight: View {
    @Environment(\.appTint) private var appTint

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            HStack(spacing: .spaceS) {
                SymbolBadge(Theme.health.symbol, color: appTint, size: .badgeS)
                Text(verbatim: Theme.health.title).font(.rowTitle).lineLimit(1)
                Spacer(minLength: .zero)
            }
            HStack(spacing: .spaceXS) {
                PartyMark("MDB")
                PartyMark("PT")
                Spacer(minLength: .zero)
            }
            ProgressBar(value: 0.7, color: .companion)
        }
        .padding(.spaceM)
        .background(.groupedRow, in: .rect(cornerRadius: .radiusM))
    }
}

private struct ThemeCanvasTabBar: View {
    @Environment(\.appTint) private var appTint

    var body: some View {
        HStack(spacing: .spaceS) {
            HStack(spacing: .spaceM) {
                ForEach(AppSection.allCases) { section in
                    Image(systemName: section.systemImage)
                        .foregroundStyle(section == .today ? appTint : Color.secondary)
                }
            }
            .padding(.spaceM)
            .background(.groupedRow, in: .capsule)
            Spacer(minLength: .zero)
        }
        .font(.icon(.s))
        .shadow(color: .black.opacity(.opacityFill), radius: .spaceXS, y: .spaceHairline)
    }
}

extension CGSize {
    fileprivate static let themeCanvas = CGSize(
        width: .themeCanvasWidth, height: .themeCanvasHeight)
}
