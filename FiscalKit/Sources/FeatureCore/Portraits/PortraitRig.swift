import FiscalResource
import Foundation
import Lottie

struct PortraitRig {
    private let document: [String: Any]
    private let layers: [[String: Any]]
    private let tones: PortraitTones

    init?(data: Data) {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let layers = root["layers"] as? [[String: Any]],
            let fiscal = root["fiscal"] as? [String: Any],
            let tones = PortraitTones(fiscal)
        else { return nil }
        var document = root
        document["fiscal"] = nil
        self.document = document
        self.layers = layers
        self.tones = tones
    }

    func neutral(slug: String, party: String) -> PortraitLibrary.Traits {
        PortraitLibrary.Traits(slug: slug, values: tones.neutral.merging(["party": party]) { $1 })
    }

    func animation(for traits: PortraitLibrary.Traits, party: String) -> LottieAnimation? {
        guard let palette = tones.palette(for: traits, party: party) else { return nil }
        var animation = document
        animation["layers"] = layers.compactMap { layer -> [String: Any]? in
            guard Self.matches(layer["fx"], traits) else { return nil }
            guard let shapes = layer["shapes"] as? [Any] else { return layer }
            var tinted = layer
            tinted["shapes"] = Self.tinted(shapes, palette)
            return tinted
        }
        return try? LottieAnimation(dictionary: animation)
    }

    private static func matches(_ selector: Any?, _ traits: PortraitLibrary.Traits) -> Bool {
        guard let selector = selector as? [String: String] else { return true }
        return selector.allSatisfy { traits[$0.key] == $0.value }
    }

    private static func tinted(_ items: [Any], _ palette: PortraitPalette) -> [Any] {
        items.map { item in
            guard var shape = item as? [String: Any] else { return item }
            if let token = shape["nm"] as? String {
                switch shape["ty"] as? String {
                case "fl", "st":
                    if let color = palette.resolve(token) {
                        shape["c"] = ["a": 0, "k": color.components]
                    }
                case "gf":
                    if var gradient = shape["g"] as? [String: Any],
                        let stops = palette.gradient(token)
                    {
                        gradient["k"] = ["a": 0, "k": stops]
                        shape["g"] = gradient
                    }
                default:
                    break
                }
            }
            if let children = shape["it"] as? [Any] {
                shape["it"] = tinted(children, palette)
            }
            return shape
        }
    }
}

struct PortraitTones {
    let ink: PortraitColor
    let paper: PortraitColor
    let skin: [PortraitColor]
    let hair: [String: PortraitColor]
    let brow: [String: PortraitColor]
    let parties: [String: [PortraitColor]]
    let fallback: [PortraitColor]
    let neutral: [String: String]
    let neutralTones: [String: String]

    init?(_ root: [String: Any]) {
        guard let ink = (root["ink"] as? String).flatMap(PortraitColor.init(hex:)),
            let paper = (root["paper"] as? String).flatMap(PortraitColor.init(hex:)),
            let skin = (root["skin"] as? [String])?.compactMap(PortraitColor.init(hex:)),
            let hair = (root["hair"] as? [String: String])?.compactMapValues(
                PortraitColor.init(hex:)),
            let brow = (root["brow"] as? [String: String])?.compactMapValues(
                PortraitColor.init(hex:)),
            let parties = (root["parties"] as? [String: [String]])?.mapValues({
                $0.compactMap(PortraitColor.init(hex:))
            }),
            let fallback = (root["fallback"] as? [String])?.compactMap(PortraitColor.init(hex:)),
            fallback.count == 2,
            let neutral = root["neutral"] as? [String: Any],
            let neutralTraits = neutral["traits"] as? [String: String],
            let neutralTones = neutral["tones"] as? [String: String]
        else { return nil }
        self.ink = ink
        self.paper = paper
        self.skin = skin
        self.hair = hair
        self.brow = brow
        self.parties = parties
        self.fallback = fallback
        self.neutral = neutralTraits
        self.neutralTones = neutralTones
    }

    func palette(for traits: PortraitLibrary.Traits, party: String) -> PortraitPalette? {
        let colors = parties[PortraitLibrary.partyKey(party)].flatMap { $0.count == 2 ? $0 : nil }
        let pair = colors ?? fallback
        guard traits["face"] != neutral["face"] else { return neutralPalette(pair) }
        guard let index = traits["skin"].flatMap(Int.init), skin.indices.contains(index - 1),
            let tone = traits["hairColor"].flatMap({ hair[$0] }) ?? hair["black"]
        else { return nil }
        return PortraitPalette(roles: [
            "skin": skin[index - 1], "hair": tone,
            "brow": traits["hairColor"].flatMap { brow[$0] } ?? tone,
            "beard": traits["beardColor"].flatMap { hair[$0] } ?? tone,
            "primary": pair[0], "secondary": pair[1], "ink": ink, "paper": paper,
        ])
    }

    private func neutralPalette(_ pair: [PortraitColor]) -> PortraitPalette? {
        let base = PortraitPalette(roles: [
            "primary": pair[0], "secondary": pair[1], "ink": ink, "paper": paper,
        ])
        var roles = base.roles
        for (role, token) in neutralTones {
            guard let color = base.resolve(token) else { return nil }
            roles[role] = color
        }
        return PortraitPalette(roles: roles)
    }
}

struct PortraitPalette {
    let roles: [String: PortraitColor]

    func resolve(_ token: String) -> PortraitColor? {
        let steps = token.split(separator: ">")
        guard let first = steps.first, var color = roles[String(first)] else { return nil }
        for step in steps.dropFirst() {
            let parts = step.split(separator: "@")
            guard parts.count == 2, let target = roles[String(parts[0])],
                let amount = Double(parts[1])
            else { return nil }
            color = color.mixed(with: target, amount: amount)
        }
        return color
    }

    func gradient(_ token: String) -> [Double]? {
        let colors = token.split(separator: ",").compactMap { resolve(String($0)) }
        guard colors.count == 2 else { return nil }
        return [0] + colors[0].channels + [1] + colors[1].channels
    }
}

struct PortraitColor: Equatable {
    let channels: [Double]

    init(channels: [Double]) {
        self.channels = channels
    }

    init?(hex: String) {
        let digits = hex.hasPrefix("#") ? hex.dropFirst() : Substring(hex)
        guard digits.count == 6, let value = Int(digits, radix: 16) else { return nil }
        channels = [16, 8, 0].map { Double((value >> $0) & 0xFF) / 255 }
    }

    var components: [Double] { channels + [1] }

    func mixed(with other: PortraitColor, amount: Double) -> PortraitColor {
        PortraitColor(
            channels: zip(channels, other.channels).map { first, second in
                ((first + (second - first) * amount) * 255).rounded() / 255
            })
    }
}
