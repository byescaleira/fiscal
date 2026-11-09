import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

struct MoneyToolbar: ToolbarContent {
    @Environment(MoneyModel.self) private var money

    var body: some ToolbarContent {
        if !money.states.isEmpty {
            ToolbarItem(placement: .primaryAction) {
                MoneyScopeMenu()
            }
        }
    }
}

private struct MoneyScopeMenu: View {
    @Environment(MoneyModel.self) private var money
    @ReducesMotion private var reduceMotion

    var body: some View {
        Menu {
            Picker("Place", selection: selection) {
                Label("Brazil", systemImage: "globe.americas").tag(MoneyPlaces.country)
                if let home = money.homeOption {
                    Section("Your Region") {
                        Label(RaceText.scope(home), systemImage: "mappin.and.ellipse")
                            .tag(home)
                    }
                }
                Section("States") {
                    ForEach(money.states.filter { $0 != money.homeOption }, id: \.self) { uf in
                        Text(verbatim: RaceText.scope(uf)).tag(uf)
                    }
                }
            }
            .pickerStyle(.inline)
        } label: {
            HStack(spacing: .spaceXS) {
                Image(systemName: "map")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.primary)
            .quietBounce(value: money.scopeUF)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Place"))
            .accessibilityValue(Text(verbatim: money.scopeName))
            .accessibilityHint(Text("Changes every block to the place picked"))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .tint(Color.primary)
        .sensoryFeedback(.selection, trigger: money.scopeUF)
    }

    private var selection: Binding<String> {
        Binding(
            get: { money.scopeUF },
            set: { uf in
                withAnimation(reduceMotion ? nil : .smooth) { money.select(scope: uf) }
            })
    }
}
