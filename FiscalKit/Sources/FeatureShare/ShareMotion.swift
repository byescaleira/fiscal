import Foundation
import SwiftUI

extension EnvironmentValues {
    @Entry public var shareProgress: Double = 1
}

public enum ShareMotion {
    public static func eased(_ progress: Double) -> Double {
        let clamped = min(max(progress, 0), 1)
        return 1 - pow(1 - clamped, 3)
    }

    public static func fill(_ share: Double, progress: Double) -> Double {
        min(max(share, 0), 1) * eased(progress)
    }

    public static func countUp(_ value: String, progress: Double) -> String {
        guard progress < 1,
            let numbers = try? Regex(#"\d{1,3}(\.\d{3})+(,\d+)?|\d+(,\d+)?"#)
        else { return value }
        return value.replacing(numbers) { match in
            scaled(String(value[match.range]), by: eased(progress))
        }
    }

    private static func scaled(_ digits: String, by factor: Double) -> String {
        let plain = digits.replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")
        guard let number = Double(plain) else { return digits }
        let decimals = digits.split(separator: ",").dropFirst().first?.count ?? 0
        return (number * factor).formatted(
            .number.precision(.fractionLength(decimals))
                .grouping(digits.contains(".") ? .automatic : .never)
                .locale(Locale(identifier: "pt_BR")))
    }
}
