import Foundation

public enum ExplainerGuard {
    static let valueWords: Set<String> = [
        "bom", "boa", "bons", "boas", "ruim", "ruins", "otimo", "otima", "pessimo", "pessima",
        "excelente", "preocupante", "alarmante", "absurdo", "absurda", "escandaloso",
        "escandalosa", "vergonhoso", "vergonhosa", "infelizmente", "felizmente",
        "lamentavelmente", "positivo", "positiva", "negativo", "negativa", "esquerda", "direita",
        "corrupto", "corrupta", "corrupcao", "impressionante", "surpreendente", "elevado",
        "elevada", "irrisorio", "irrisoria", "exagerado", "exagerada", "polemico", "polemica",
    ]

    public static func clean(_ text: String) -> String {
        let stripped = text.replacing(/[*#_`>]/, with: "")
        return stripped.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    public static func accepts(_ text: String, facts: [String], isFinal: Bool) -> Bool {
        let source = facts.joined(separator: " ")
        let words = Self.words(in: text)
        let checked = isFinal ? words : Array(words.dropLast())
        let sourceWords = Set(Self.words(in: source))
        if checked.contains(where: { valueWords.contains($0) && !sourceWords.contains($0) }) {
            return false
        }
        let numbers = text.matches(of: /\d+/).map { String($0.output) }
        let checkedNumbers = isFinal ? numbers : Array(numbers.dropLast())
        guard checkedNumbers.allSatisfy(source.contains) else { return false }
        return !isFinal || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public static func limited(_ text: String, sentences limit: Int = Explanation.sentenceLimit)
        -> String
    {
        var sentences: [String] = []
        text.enumerateSubstrings(in: text.startIndex..., options: .bySentences) {
            substring, _, _, stop in
            if let sentence = substring?.trimmingCharacters(in: .whitespacesAndNewlines),
                !sentence.isEmpty
            {
                sentences.append(sentence)
            }
            stop = sentences.count >= limit
        }
        return sentences.joined(separator: " ")
    }

    static func words(in text: String) -> [String] {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .split { !$0.isLetter }
            .map(String.init)
    }
}
