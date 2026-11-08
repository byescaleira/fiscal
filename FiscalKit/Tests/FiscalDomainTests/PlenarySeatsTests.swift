import Testing

@testable import FiscalDomain

struct PlenarySeatsTests {
    @Test func countsWhoDidNotVote() throws {
        let seats = try #require(PlenarySeats(yes: 252, no: 176, others: 1, seats: 513))
        #expect(seats.absent == 84)
        #expect(seats.requiredYes == nil)
    }

    @Test func keepsTheRequiredYesInsideTheHouse() throws {
        let senate = try #require(
            PlenarySeats(yes: 75, no: 1, others: 3, seats: 81, requiredYes: 49))
        #expect(senate.absent == 2)
        #expect(senate.requiredYes == 49)
        let wrong = try #require(
            PlenarySeats(yes: 75, no: 1, others: 3, seats: 81, requiredYes: 90))
        #expect(wrong.requiredYes == nil)
    }

    @Test(arguments: [(600, 0, 0, 513), (-1, 0, 0, 81), (0, 0, 0, 0), (0, -2, 0, 81)])
    func refusesNumbersThatDoNotFit(yes: Int, no: Int, others: Int, seats: Int) {
        #expect(PlenarySeats(yes: yes, no: no, others: others, seats: seats) == nil)
    }
}
