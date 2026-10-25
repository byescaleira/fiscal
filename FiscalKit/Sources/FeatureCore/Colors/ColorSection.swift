import FiscalDesignSystem
import SwiftUI

public struct ColorSection: View {
    @Binding private var hex: String
    private let footer: String?

    public init(hex: Binding<String>, footer: String? = nil) {
        _hex = hex
        self.footer = footer
    }

    public var body: some View {
        Section {
            RetroColorPicker(hex: $hex)
        } header: {
            HStack(alignment: .firstTextBaseline) {
                Text("Color").sectionTitle()
                Spacer()
                Text(RetroColor.name(for: hex))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(hex: hex))
                    .lineLimit(1)
            }
        } footer: {
            if let footer { Text(footer) }
        }
    }
}
