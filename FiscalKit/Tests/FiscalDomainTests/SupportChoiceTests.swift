import Testing

@testable import FiscalDomain

struct SupportChoiceTests {
    @Test func everyThemeIsOfferedOnceAsACause() {
        #expect(Set(Theme.causeChoices) == Set(Theme.allCases))
        #expect(Theme.causeChoices.count == Theme.allCases.count)
        #expect(Theme.allCases.allSatisfy { !$0.coverage.isEmpty })
    }

    @Test func keepsAtMostFivePeopleAndFiveCausesWithoutRepeating() {
        let choice = SupportChoice(
            people: ["a", "a", "b", "c", "d", "e", "f"],
            causes: [.health, .health, .taxes, .security, .education, .rights, .women])
        #expect(choice.people == ["a", "b", "c", "d", "e"])
        #expect(choice.causes == [.health, .taxes, .security, .education, .rights])
        #expect(!choice.canAddPerson)
        #expect(!choice.canAddCause)
    }

    @Test func aSixthPersonOrCauseIsIgnored() {
        var choice = SupportChoice(
            people: ["a", "b", "c", "d", "e"],
            causes: [.health, .taxes, .security, .education, .rights])
        choice.togglePerson("f")
        choice.toggleCause(.women)
        #expect(choice.people.count == SupportChoice.peopleLimit)
        #expect(choice.causes.count == SupportChoice.causeLimit)
    }

    @Test func thereIsNoMinimumAndTogglingRemoves() {
        var choice = SupportChoice()
        #expect(choice.isEmpty)
        choice.toggleCause(.health)
        #expect(!choice.isEmpty)
        #expect(choice.contains(.health))
        choice.toggleCause(.health)
        choice.togglePerson("a")
        #expect(choice.supports("a"))
        #expect(choice.rank(of: "a") == 0)
        choice.togglePerson("a")
        #expect(choice.isEmpty)
        #expect(!choice.supports(nil))
    }
}
