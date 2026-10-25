import FeatureCore
import FiscalDesignSystem
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
                            HStack(spacing: 0) {
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
                .stroke(.separator, lineWidth: 1)
        }
        .dynamicTypeSize(.large)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct ThemeCanvas: View {
    @Environment(SettingsModel.self) private var settings

    var body: some View {
        let sample = settings.themeSample
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: .spaceM) {
                Text(sample.title).font(.titleLarge)
                VStack(alignment: .leading, spacing: .space2XS) {
                    Text(sample.caption).font(.rowDetail).foregroundStyle(.secondary)
                    Text(sample.headline).font(.amountTitle).amountLine()
                }
                VStack(spacing: .spaceM) {
                    ForEach(sample.rows) { ThemeCanvasRow(row: $0) }
                }
                .padding(.spaceM)
                .frame(maxWidth: .infinity)
                .background(.groupedRow, in: .rect(cornerRadius: .radiusM))
                Spacer(minLength: 0)
                ThemeCanvasTabBar()
            }
            .padding(.spaceL)
            .foregroundStyle(.primary)
            .frame(
                width: CGSize.themeCanvas.width, height: CGSize.themeCanvas.height,
                alignment: .topLeading
            )
            .background(.groupedBackground)
            .scaleEffect(proxy.size.width / CGSize.themeCanvas.width, anchor: .topLeading)
        }
    }
}

private struct ThemeCanvasRow: View {
    @Environment(\.appTint) private var appTint
    let row: ThemeSample.Row

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            HStack(spacing: .spaceS) {
                SymbolBadge(row.symbol, color: row.color.color, size: .badgeS)
                Text(row.title).font(.rowTitle).lineLimit(1)
                Spacer(minLength: 0)
            }
            ProgressBar(value: row.fraction, color: appTint)
            Text(row.detail).font(.rowDetail).foregroundStyle(.secondary)
        }
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
            .padding(.horizontal, .spaceM)
            .padding(.vertical, .spaceM)
            .background(.groupedRow, in: .capsule)
            Spacer(minLength: 0)
        }
        .font(.icon(.s))
        .shadow(color: .black.opacity(.opacityFill), radius: 6, y: 2)
    }
}

extension CGSize {
    fileprivate static let themeCanvas = CGSize(width: 240, height: 400)
}
