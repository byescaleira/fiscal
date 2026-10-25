import SwiftUI

public struct PersonPortrait: View {
    private let slug: String
    private let name: String
    private let party: String
    private let size: CGFloat

    public init(slug: String, name: String, party: String, size: CGFloat = .badgeL) {
        self.slug = slug
        self.name = name
        self.party = party
        self.size = size
    }

    public var body: some View {
        Text(initials)
            .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(PartyPalette.of(party: party).gradient, in: .circle)
            .accessibilityHidden(true)
    }

    var initials: String {
        let words = name.split(separator: " ").filter { $0.count > 2 }
        let letters = [words.first, words.count > 1 ? words.last : nil].compactMap { $0?.first }
        return String(letters).uppercased()
    }
}
