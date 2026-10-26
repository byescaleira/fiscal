import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct MoneyToolbar: ToolbarContent {
    @Environment(MoneyModel.self) private var money

    var body: some ToolbarContent {
        if !money.mandateStates.isEmpty {
            ToolbarItem(placement: .primaryAction) {
                MandateStateMenu()
            }
        }
    }
}

private struct MandateStateMenu: View {
    @Environment(MoneyModel.self) private var money

    var body: some View {
        @Bindable var money = money
        Menu {
            Picker("State", selection: $money.selectedUF) {
                ForEach(money.mandateStates, id: \.self) { uf in
                    Text(verbatim: RaceText.scope(uf)).tag(uf)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Label("Office allowance state", systemImage: "map")
                .labelStyle(.iconOnly)
                .foregroundStyle(Color.primary)
                .symbolEffect(.bounce, value: money.selectedUF)
                .accessibilityValue(Text(verbatim: money.mandateUFName))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .tint(Color.primary)
    }
}
