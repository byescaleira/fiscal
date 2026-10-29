import FeatureCore
import FiscalDomain
import Foundation
import Observation

@MainActor @Observable
public final class StudyGuideModel {
    public let id: String
    public private(set) var phase: PublicDataPhase = .idle
    public private(set) var catalog: StudyCatalog?
    public private(set) var answers: [Int: Int] = [:]
    public var query = ""
    @ObservationIgnored private let service: (any PublicDataService)?

    public init(id: String, service: (any PublicDataService)?) {
        self.id = id
        self.service = service
    }

    var guide: StudyGuide? { catalog?.guides.first { $0.id == id } }

    var terms: [StudyTerm] {
        let all = guide?.terms ?? []
        let words = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .app)
            .trimmingCharacters(in: .whitespaces)
        guard !words.isEmpty else { return all }
        return all.filter {
            "\($0.term) \($0.definition)"
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .app)
                .contains(words)
        }
    }

    var answered: Int { answers.count }

    var correct: Int {
        guard let quiz = guide?.quiz else { return 0 }
        return answers.filter { quiz.indices.contains($0.key) && quiz[$0.key].answer == $0.value }
            .count
    }

    var progressLine: String {
        let total = guide?.quiz.count ?? 0
        guard answered == total, total > 0 else {
            return String(appLocalized: "\(answered) of \(total) answered")
        }
        return String(appLocalized: "\(correct) of \(total) right")
    }

    var heroChip: String {
        guard let guide else { return "" }
        return guide.countText.uppercased(with: .app)
    }

    public func load() async {
        guard let service else {
            phase = .failed(.unavailable)
            return
        }
        if catalog == nil { phase = .loading }
        phase = await PublicDataPhase.settle(after: phase) {
            catalog = try await service.studyCatalog()
        }
    }

    func choose(_ option: Int, for question: Int) {
        guard answers[question] == nil else { return }
        answers[question] = option
    }

    func restart() {
        answers = [:]
    }
}
