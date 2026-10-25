import SwiftUI

public struct PartyMark: View {
    private let party: String

    public init(_ party: String) {
        self.party = party
    }

    public var body: some View {
        Text(party.uppercased())
            .font(.chipLabel)
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, .spaceS)
            .padding(.vertical, .space2XS)
            .background(PartyPalette.of(party: party).gradient, in: .capsule)
            .accessibilityLabel(Text("Party \(party)"))
    }
}
