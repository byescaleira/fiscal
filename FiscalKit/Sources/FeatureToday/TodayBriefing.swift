import FiscalDomain
import Foundation

public struct LensOrdered<Value: Hashable>: Hashable {
    public let value: Value
    public let offset: Int
    public let isLensPick: Bool
}

extension LensOrdered: Identifiable {
    public var id: Int { offset }
}

public enum TodayBriefing {
    public enum Mode: Equatable, Sendable {
        case plain
        case themes([Theme])
    }

    public static func mode(for lens: Lens?) -> Mode {
        guard let lens else { return .plain }
        return lens.themes.isEmpty ? .plain : .themes(lens.themes)
    }

    public static func order<Value: Hashable>(
        _ values: [Value], mode: Mode, themes: (Value) -> [Theme]
    ) -> [LensOrdered<Value>] {
        let offsets: [Int]
        switch mode {
        case .plain: offsets = Array(values.indices)
        case .themes(let chosen):
            offsets = values.indices.sorted { lhs, rhs in
                (rank(themes(values[lhs]), in: chosen), lhs)
                    < (rank(themes(values[rhs]), in: chosen), rhs)
            }
        }
        return offsets.enumerated().map { position, offset in
            LensOrdered(value: values[offset], offset: offset, isLensPick: position < offset)
        }
    }

    public static func rank(_ themes: [Theme], in chosen: [Theme]) -> Int {
        themes.compactMap { chosen.firstIndex(of: $0) }.min() ?? chosen.count
    }
}
