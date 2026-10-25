import SwiftUI

public struct PortraitRequest: Sendable, Hashable {
    public let slug: String
    public let party: String
    public let isStill: Bool

    public init(slug: String, party: String, isStill: Bool) {
        self.slug = slug
        self.party = party
        self.isStill = isStill
    }
}

public struct PortraitArtwork: Sendable {
    private let render: @MainActor @Sendable (PortraitRequest) -> AnyView?

    public init(_ render: @escaping @MainActor @Sendable (PortraitRequest) -> AnyView?) {
        self.render = render
    }

    @MainActor
    public func view(for request: PortraitRequest) -> AnyView? {
        render(request)
    }
}

extension EnvironmentValues {
    @Entry public var portraitArtwork: PortraitArtwork?
    @Entry public var portraitsAreStill = false
}

extension View {
    public func portraitArtwork(_ artwork: PortraitArtwork?) -> some View {
        environment(\.portraitArtwork, artwork)
    }

    public func portraitsStill(_ isStill: Bool = true) -> some View {
        environment(\.portraitsAreStill, isStill)
    }
}
