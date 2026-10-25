import FiscalDesignSystem
import SwiftUI

public struct RetroColorPicker: View {
    @Binding private var hex: String

    public init(hex: Binding<String>) {
        _hex = hex
    }

    public var body: some View {
        let selection = RetroColor(hex: hex)
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 44, maximum: 44), spacing: .spaceM)],
            spacing: .spaceM
        ) {
            ForEach(RetroColor.allCases) { color in
                ColorChoice(color: color, isSelected: color == selection) { hex = color.hex }
            }
        }
        .padding(.vertical, .spaceS)
        .sensoryFeedback(.selection, trigger: hex)
    }
}

private struct ColorChoice: View {
    let color: RetroColor
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color.color)
                .frame(width: 36, height: 36)
                .overlay {
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }
                .overlay {
                    if isSelected {
                        Circle().stroke(color.color, lineWidth: 2).frame(width: 44, height: 44)
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(color.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
