import Foundation

extension Race {
    public var isDecided: Bool {
        final || sections.percent >= 100 || candidates.contains(where: \.elected)
    }

    public var winner: RaceCandidate? {
        guard isDecided else { return nil }
        if let elected { return elected }
        return round == 2 || candidates.count <= 2 ? candidates.first : nil
    }
}
