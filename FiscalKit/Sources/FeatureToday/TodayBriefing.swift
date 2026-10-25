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
        case plain, alternating
        case themes([Theme])
    }

    public static let audiences: [[Theme]] = [
        [.taxes, .security, .politics, .economy, .countryside],
        [.social, .environment, .rights, .health, .education],
    ]

    public static func mode(for lens: Lens?) -> Mode {
        guard let lens else { return .plain }
        if lens.stance?.isImpartial == true { return .alternating }
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
        case .alternating:
            offsets = alternate(values.map(themes))
        }
        return offsets.enumerated().map { position, offset in
            LensOrdered(value: values[offset], offset: offset, isLensPick: position < offset)
        }
    }

    public static func rank(_ themes: [Theme], in chosen: [Theme]) -> Int {
        themes.compactMap { chosen.firstIndex(of: $0) }.min() ?? chosen.count
    }

    static func alternate(_ themes: [[Theme]]) -> [Int] {
        let queues = audiences.map { audience in
            themes.indices
                .filter { rank(themes[$0], in: audience) < audience.count }
                .sorted {
                    (rank(themes[$0], in: audience), $0) < (rank(themes[$1], in: audience), $1)
                }
        }
        var picked: [Int] = []
        var turn = 0
        while true {
            let next = (0..<queues.count).lazy
                .map { queues[(turn + $0) % queues.count] }
                .compactMap { queue in queue.first { !picked.contains($0) } }
                .first
            guard let next else { break }
            picked.append(next)
            turn += 1
        }
        return picked + themes.indices.filter { !picked.contains($0) }
    }
}
