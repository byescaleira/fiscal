import FiscalDesignSystem
import Testing

struct ProgressBarTests {
    @Test(arguments: [
        (-0.5, 0.0),
        (0.0, 0.0),
        (0.42, 0.42),
        (1.0, 1.0),
        (2.5, 1.0),
    ])
    func clampsTheValueBetweenZeroAndOne(value: Double, expected: Double) {
        #expect(ProgressBar.clamped(value) == expected)
    }

    @Test func notANumberBecomesEmpty() {
        #expect(ProgressBar.clamped(.nan) == 0)
    }
}
