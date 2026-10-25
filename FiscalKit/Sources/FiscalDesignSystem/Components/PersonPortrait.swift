import SwiftUI

public struct PersonPortrait: View {
    @Environment(\.portraitArtwork) private var artwork
    @Environment(\.portraitsAreStill) private var portraitsAreStill
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
        content
            .frame(width: size, height: size)
            .clipShape(.circle)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Illustration of \(name)"))
            .accessibilityAddTraits(.isImage)
    }

    @ViewBuilder private var content: some View {
        if let drawn = artwork?.view(for: request) {
            drawn
        } else {
            GenericPortrait(initials: initials, party: party, size: size)
        }
    }

    var request: PortraitRequest {
        PortraitRequest(slug: slug, party: party, isStill: portraitsAreStill || reduceMotion)
    }

    var initials: String {
        let words = name.split(separator: " ").filter { $0.count > 2 }
        let letters = [words.first, words.count > 1 ? words.last : nil].compactMap { $0?.first }
        return String(letters).uppercased()
    }
}

struct GenericPortrait: View {
    private static let shouldersWidth = 0.84
    private static let shouldersHeight = 0.52
    private static let shouldersDrop = 0.4
    private static let initialsScale = 0.34
    private static let initialsLift = 0.07
    private static let minimumScale = 0.5

    let initials: String
    let party: String
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(.fill.secondary)
            Ellipse()
                .fill(.fill.tertiary)
                .frame(width: size * Self.shouldersWidth, height: size * Self.shouldersHeight)
                .offset(y: size * Self.shouldersDrop)
            Text(initials)
                .font(.system(size: size * Self.initialsScale, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .minimumScaleFactor(Self.minimumScale)
                .offset(y: -size * Self.initialsLift)
        }
    }
}
