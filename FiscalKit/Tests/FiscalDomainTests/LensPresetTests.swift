import FiscalDomain
import Testing

struct LensPresetTests {
    @Test(arguments: PoliticalStance.allCases)
    func everySidePreMarksThreeToFiveTopics(stance: PoliticalStance) {
        let preset = LensPreset.suggested(for: stance)
        #expect(Lens.themeRange.contains(preset.themes.count))
        #expect(Set(preset.themes).count == preset.themes.count)
        #expect(preset.themes.allSatisfy(Theme.setupChoices.contains))
        let lens = preset.lens(stance: stance)
        #expect(lens.isComplete)
        #expect(lens.stance == stance)
    }

    @Test func mirroredSidesGetTheSameNumberOfTopics() {
        let pairs: [(PoliticalStance, PoliticalStance)] = [
            (.right, .left), (.centerRight, .centerLeft),
        ]
        for (one, other) in pairs {
            #expect(
                LensPreset.suggested(for: one).themes.count
                    == LensPreset.suggested(for: other).themes.count)
            #expect(one.counterpart == other)
            #expect(other.counterpart == one)
        }
    }

    @Test func centerHasItsOwnPackage() {
        let center = LensPreset.suggested(for: .center)
        #expect(center != LensPreset.suggested(for: .impartial))
        #expect(center != LensPreset.suggested(for: .right))
        #expect(center != LensPreset.suggested(for: .left))
    }

    @Test func impartialBalancesBothPublics() {
        let impartial = Set(LensPreset.suggested(for: .impartial).themes)
        let right = Set(LensPreset.suggested(for: .right).themes)
        let left = Set(LensPreset.suggested(for: .left).themes)
        #expect(!impartial.isDisjoint(with: right.subtracting(left)))
        #expect(!impartial.isDisjoint(with: left.subtracting(right)))
        #expect(LensPreset.suggested(for: .preferNotToSay) == LensPreset.suggested(for: .impartial))
    }

    @Test func setupShowsTwelveTopicsAndKeepsTheRestOneTapAway() {
        #expect(Theme.setupChoices.count == 12)
        #expect(Theme.moreChoices.count == Theme.allCases.count - 12)
        #expect(Set(Theme.setupChoices + Theme.moreChoices) == Set(Theme.allCases))
    }
}
