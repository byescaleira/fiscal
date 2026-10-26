import Testing

@testable import FeatureCore

struct BallotChoiceTests {
    @Test(arguments: [
        ("Sim", BallotChoice.yes), ("NÃO", .no), ("nao", .no), ("Abstenção", .abstain),
        ("Obstrução", .abstain), ("Art. 17", .abstain), ("Ausente", .absent),
    ])
    func readsTheOfficialVote(text: String, choice: BallotChoice) {
        #expect(BallotChoice(vote: text) == choice)
    }

    @Test func freeVoteAndBlankHaveNoChoice() {
        #expect(BallotChoice(vote: "Liberado") == nil)
        #expect(BallotChoice(vote: " ") == nil)
    }

    @Test func everyChoiceHasItsOwnSymbol() {
        let symbols = BallotChoice.allCases.map(\.symbol)
        #expect(Set(symbols).count == BallotChoice.allCases.count)
    }
}
