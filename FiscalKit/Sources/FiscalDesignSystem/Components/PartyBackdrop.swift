import SwiftUI

extension Double {
    public static let opacityScrimTop = 0.4
    public static let opacityScrim = 0.6
}

public struct PartyBackdrop: View {
    private let party: String

    public init(party: String) {
        self.party = party
    }

    public var body: some View {
        ZStack {
            PartyPalette.of(party: party).gradient
            LinearGradient(
                colors: [
                    Color.scoreboard.opacity(.opacityScrimTop),
                    Color.scoreboard.opacity(.opacityScrim),
                ], startPoint: .top, endPoint: .bottom)
        }
        .accessibilityHidden(true)
    }
}
