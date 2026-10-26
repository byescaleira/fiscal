import FiscalDesignSystem
import SwiftUI

extension MoneyTone {
    var color: Color {
        switch self {
        case .teal: .retroTeal
        case .denim: .retroDenim
        case .plum: .retroPlum
        case .brown: .retroBrown
        case .orange: .retroOrange
        }
    }
}

extension AmountBar {
    var color: Color { ChartPalette.color(at: slot) }

    var ranked: RankedBar {
        RankedBar(
            id: id, title: title, symbol: kind.symbol, value: reais, valueText: value,
            details: [percent] + (detail.map { [$0] } ?? []), color: color)
    }
}
