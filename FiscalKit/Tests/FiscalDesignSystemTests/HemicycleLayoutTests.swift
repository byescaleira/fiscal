import Foundation
import Testing

@testable import FiscalDesignSystem

struct HemicycleLayoutTests {
    @Test(arguments: [(252, 176, 1, 513), (75, 1, 3, 81), (0, 0, 0, 513)])
    func placesOneSeatPerMember(yes: Int, no: Int, others: Int, seats: Int) {
        let layout = HemicycleLayout(yes: yes, no: no, others: others, seats: seats)
        #expect(layout.count == seats)
        #expect(layout.seatsPerRow.reduce(0, +) == seats)
        #expect(layout.count(of: .yes) == yes)
        #expect(layout.count(of: .no) == no)
        #expect(layout.count(of: .other) == others)
        #expect(layout.count(of: .absent) == seats - yes - no - others)
    }

    @Test func leavesTwoSenateSeatsForWhoDidNotVote() {
        let layout = HemicycleLayout(yes: 75, no: 1, others: 3, seats: 81)
        #expect(layout.count(of: .absent) == 2)
    }

    @Test func putsYesOnTheLeftAndNoOnTheRight() {
        let layout = HemicycleLayout(yes: 252, no: 176, others: 1, seats: 513)
        let byAngle = layout.seats.sorted { $0.angle > $1.angle }
        #expect(byAngle.prefix(252).allSatisfy { $0.group == .yes })
        #expect(byAngle.suffix(176).allSatisfy { $0.group == .no })
    }

    @Test func countsBothSidesAtTheSamePace() {
        let layout = HemicycleLayout(yes: 252, no: 176, others: 1, seats: 513)
        let yesRanks = layout.seats.filter { $0.group == .yes }.map(\.rank).sorted()
        let noRanks = layout.seats.filter { $0.group == .no }.map(\.rank).sorted()
        #expect(yesRanks.first == 0)
        #expect(noRanks.first == 0)
        #expect(layout.lastRank == 252 + 85 - 1)
    }

    @Test func spreadsTheSeatsOverRows() {
        let layout = HemicycleLayout(yes: 75, no: 1, others: 3, seats: 81)
        #expect(layout.seatsPerRow.count > 1)
        #expect(layout.seatsPerRow == layout.seatsPerRow.sorted())
    }

    @Test(arguments: [(513, 308), (81, 49)])
    func marksTheRequiredYesBetweenTwoSeats(seats: Int, required: Int) {
        let layout = HemicycleLayout(yes: 1, no: 1, others: 0, seats: seats)
        let angle = layout.angle(beforeSeat: required)
        let sorted = layout.seats.map(\.angle).sorted(by: >)
        #expect(sorted[required - 1] >= angle)
        #expect(angle >= sorted[required])
    }
}
