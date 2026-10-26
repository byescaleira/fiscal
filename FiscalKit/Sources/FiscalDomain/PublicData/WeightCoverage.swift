import Foundation

public enum WeightSignal: String, CaseIterable, Codable, Hashable, Sendable {
    case news, newsPerson, wiki, wikiTheme, bluesky

    public static let weighted: [WeightSignal] = [.news, .newsPerson, .wiki, .wikiTheme]
    public static let personal: Set<WeightSignal> = [.newsPerson, .wiki]
}

public struct WeightCoverage: Hashable, Sendable {
    public enum Confidence: String, Codable, Hashable, Sendable {
        case full, partial, impactOnly
    }

    public let measured: [WeightSignal]
    public let missing: [WeightSignal]
    public let confidence: Confidence

    public init(measured: [WeightSignal], missing: [WeightSignal], confidence: Confidence) {
        self.measured = measured
        self.missing = missing
        self.confidence = confidence
    }

    public init(
        measured: [String]?, missing: [String]?, confidence: String?, signals: WeightSignals,
        personal: Bool
    ) {
        if let measured, let missing,
            let confidence = confidence.flatMap(Confidence.init(rawValue:))
        {
            self.init(
                measured: measured.compactMap(WeightSignal.init(rawValue:)),
                missing: missing.compactMap(WeightSignal.init(rawValue:)),
                confidence: confidence)
            return
        }
        self.init(signals: signals, personal: personal)
    }

    public init(signals: WeightSignals, personal: Bool) {
        let expected = WeightSignal.weighted.filter {
            personal || !WeightSignal.personal.contains($0)
        }
        let found = expected.filter { signals.value(of: $0) != nil }
        var absent = expected.filter { signals.value(of: $0) == nil }
        if signals.bluesky == nil { absent.append(.bluesky) }
        let confidence: Confidence =
            found.isEmpty ? .impactOnly : found.count == expected.count ? .full : .partial
        self.init(measured: found, missing: absent, confidence: confidence)
    }

    public var isMeasured: Bool { confidence == .full }

    public var uncertainty: String? {
        switch confidence {
        case .full:
            return nil
        case .partial:
            let found = Self.list(Self.names(measured))
            let parts = Self.names(missing)
            let absent = Self.list(parts)
            if parts.isEmpty {
                return String(appLocalized: "Estimated: repercussion measured only with \(found).")
            }
            return parts.count == 1
                ? String(
                    appLocalized:
                        "Estimated: repercussion measured only with \(found); \(absent) was missing in this load."
                )
                : String(
                    appLocalized:
                        "Estimated: repercussion measured only with \(found); \(absent) were missing in this load."
                )
        case .impactOnly:
            let absent = Self.list(Self.names(missing))
            return String(
                appLocalized:
                    "Estimated: weight from impact only; no repercussion signal was measured in this load (missing \(absent))."
            )
        }
    }

    public var uncertaintyShort: String? {
        switch confidence {
        case .full: nil
        case .partial: String(appLocalized: "Estimated: only \(Self.list(Self.names(measured)))")
        case .impactOnly: String(appLocalized: "Estimated: impact only")
        }
    }

    public func spoken(weight: Int, repercussion: Int?, impact: Int) -> String {
        let base =
            if let repercussion {
                String(
                    appLocalized:
                        "Weight \(weight) of 100, repercussion \(repercussion), impact \(impact).")
            } else {
                String(
                    appLocalized:
                        "Weight \(weight) of 100, impact \(impact), repercussion not measured.")
            }
        return [base, uncertainty].compactMap(\.self).joined(separator: " ")
    }

    static func list(_ parts: [String]) -> String {
        parts.formatted(.list(type: .and).locale(.app))
    }

    static func names(_ signals: [WeightSignal]) -> [String] {
        let set = Set(signals)
        var parts: [String] = []
        switch (set.contains(.news), set.contains(.newsPerson)) {
        case (true, true): parts.append(String(appLocalized: "news"))
        case (true, false): parts.append(String(appLocalized: "news about the bill"))
        case (false, true): parts.append(String(appLocalized: "news citing the politician"))
        case (false, false): break
        }
        switch (set.contains(.wiki), set.contains(.wikiTheme)) {
        case (true, true): parts.append(String(appLocalized: "Wikipedia"))
        case (true, false): parts.append(String(appLocalized: "the politician's Wikipedia article"))
        case (false, true): parts.append(String(appLocalized: "the theme's Wikipedia article"))
        case (false, false): break
        }
        if set.contains(.bluesky) { parts.append("Bluesky") }
        return parts
    }
}

extension WeightSignals {
    public func value(of signal: WeightSignal) -> Int? {
        switch signal {
        case .news: news
        case .newsPerson: newsPerson
        case .wiki: wiki
        case .wikiTheme: wikiTheme
        case .bluesky: bluesky
        }
    }
}
