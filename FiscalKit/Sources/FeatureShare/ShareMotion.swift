import FiscalDesignSystem
import Foundation
import SwiftUI

extension EnvironmentValues {
    @Entry public var shareProgress: Double = 1
    @Entry public var shareShowsArt = true
}

public enum ShareMotion {
    public static let settled = 0.55
    static let stageStart = 0.02
    static let stageStep = 0.035
    static let stageLength = 0.14
    static let rollStart = 0.12
    static let rollLength = 0.33
    static let fillStart = 0.2
    static let fillLength = 0.3

    public static func eased(_ progress: Double) -> Double {
        let clamped = min(max(progress, 0), 1)
        return 1 - pow(1 - clamped, 3)
    }

    static func local(_ progress: Double, start: Double, length: Double) -> Double {
        min(max((progress - start) / length, 0), 1)
    }

    public static func stage(_ order: Int, progress: Double) -> Double {
        eased(
            local(progress, start: stageStart + Double(order) * stageStep, length: stageLength))
    }

    public static func fill(_ share: Double, progress: Double) -> Double {
        min(max(share, 0), 1) * eased(local(progress, start: fillStart, length: fillLength))
    }

    public static func art(_ progress: Double) -> Double {
        eased(local(progress, start: 0, length: settled))
    }

    public static func figureOpacity(_ progress: Double) -> Double {
        progress >= rollStart ? 1 : 0
    }

    public static func rolled(_ value: String, progress: Double) -> String {
        let roll = local(progress, start: rollStart, length: rollLength)
        guard roll < 1, !value.contains("/"),
            let numbers = try? Regex(#"\d{1,3}(\.\d{3})+(,\d+)?|\d+(,\d+)?"#)
        else { return value }
        return value.replacing(numbers) { match in
            scaled(String(value[match.range]), by: eased(roll))
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

private struct ShareReveal: ViewModifier {
    @Environment(\.shareProgress) private var progress
    let order: Int

    func body(content: Content) -> some View {
        let stage = ShareMotion.stage(order, progress: progress)
        content
            .opacity(stage)
            .offset(y: (1 - stage) * .shareRevealDrop)
    }
}

extension View {
    func shareReveal(_ order: Int) -> some View {
        modifier(ShareReveal(order: order))
    }
}
