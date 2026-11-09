import FiscalDesignSystem
import SwiftUI

struct RaceCountBar: View {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.liteMode) private var liteMode
    @State private var revealed = false
    let value: Double
    let color: Color

    var body: some View {
        ProgressBar(value: revealed ? value : 0, color: color)
            .onAppear {
                let reduced = systemReduceMotion || liteMode.reducesMotion
                withAnimation(reduced ? nil : .chartReveal(0)) { revealed = true }
            }
    }
}
