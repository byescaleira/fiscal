import CoreGraphics
import FiscalResource
import Foundation
import Lottie
import Observation

@MainActor
@Observable
public final class PortraitStore {
    public static let stillSide: CGFloat = 480

    public let library: PortraitLibrary
    public private(set) var downloaded: [String: PortraitLibrary.Entry] = [:]
    @ObservationIgnored private var downloadedData: [String: Data] = [:]
    @ObservationIgnored private var parsed: [String: LottieAnimation] = [:]
    @ObservationIgnored private var stills: [String: CGImage] = [:]
    @ObservationIgnored private var sealAnimation: LottieAnimation?

    public init(library: PortraitLibrary = .bundled) {
        self.library = library
    }

    public func hasPortrait(slug: String, party: String) -> Bool {
        data(slug: slug, party: party) != nil
    }

    public func animation(slug: String, party: String) -> LottieAnimation? {
        guard let data = data(slug: slug, party: party) else { return nil }
        if let cached = parsed[slug] { return cached }
        guard let animation = try? LottieAnimation.from(data: data) else { return nil }
        parsed[slug] = animation
        return animation
    }

    public func still(slug: String, party: String) -> CGImage? {
        if let cached = stills[slug], hasPortrait(slug: slug, party: party) { return cached }
        guard let animation = animation(slug: slug, party: party),
            let image = PortraitStill.render(animation, side: Self.stillSide)
        else { return nil }
        stills[slug] = image
        return image
    }

    public var seal: LottieAnimation? {
        if let sealAnimation { return sealAnimation }
        guard let data = library.seal, let animation = try? LottieAnimation.from(data: data) else {
            return nil
        }
        sealAnimation = animation
        return animation
    }

    public func install(_ data: Data, for entry: PortraitLibrary.Entry) throws {
        guard let animation = try? LottieAnimation.from(data: data), animation.duration > 0 else {
            throw PortraitStoreError.invalidAnimation
        }
        downloaded[entry.slug] = entry
        downloadedData[entry.slug] = data
        parsed[entry.slug] = animation
        stills[entry.slug] = nil
    }

    private func data(slug: String, party: String) -> Data? {
        if let entry = downloaded[slug] {
            guard PortraitLibrary.sameParty(entry.party, party) else { return nil }
            return downloadedData[slug]
        }
        return library.animationData(for: slug, party: party)
    }
}

public enum PortraitStoreError: Error, Equatable {
    case invalidAnimation
}
