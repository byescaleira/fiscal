import CoreGraphics
import FiscalDesignSystem
import FiscalResource
import Foundation
import Lottie
import Observation

@MainActor
@Observable
public final class PortraitStore {
    public static let stillSide: CGFloat = 480
    private static let cacheLimit = 160

    public let library: PortraitLibrary
    @ObservationIgnored private var loadedRig: PortraitRig?
    @ObservationIgnored private var assembled: [String: LottieAnimation] = [:]
    @ObservationIgnored private var stills: [String: CGImage] = [:]
    @ObservationIgnored private var sealAnimation: LottieAnimation?

    public init(library: PortraitLibrary = .bundled) {
        self.library = library
    }

    public func hasPortrait(slug: String, party: String) -> Bool {
        library.rig != nil && library.traits(for: slug, party: party) != nil
    }

    public func animation(slug: String, party: String) -> LottieAnimation? {
        guard let traits = library.traits(for: slug, party: party) else { return nil }
        let key = Self.key(slug: slug, party: party)
        if let cached = assembled[key] { return cached }
        guard let animation = rig()?.animation(for: traits, party: party) else { return nil }
        if assembled.count >= Self.cacheLimit { assembled.removeAll(keepingCapacity: true) }
        assembled[key] = animation
        return animation
    }

    public func still(slug: String, party: String, pose: PortraitExpression? = nil) -> CGImage? {
        let key = Self.key(slug: slug, party: party) + "|" + (pose?.rawValue ?? "")
        if let cached = stills[key] { return cached }
        guard let animation = animation(slug: slug, party: party) else { return nil }
        let frame = pose.flatMap { animation.frameTime(forMarker: $0.poseMarker) } ?? 0
        guard let image = PortraitStill.render(animation, side: Self.stillSide, frame: frame)
        else { return nil }
        if stills.count >= Self.cacheLimit { stills.removeAll(keepingCapacity: true) }
        stills[key] = image
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

    private func rig() -> PortraitRig? {
        if let loadedRig { return loadedRig }
        loadedRig = library.rig.flatMap(PortraitRig.init(data:))
        return loadedRig
    }

    private static func key(slug: String, party: String) -> String {
        slug + "|" + PortraitLibrary.partyKey(party)
    }
}

extension PortraitExpression {
    static let idleMarker = "idle"

    var marker: String { rawValue }

    var poseMarker: String { rawValue + "Pose" }

    var loopMarker: String? { self == .think ? "thinkLoop" : nil }
}
