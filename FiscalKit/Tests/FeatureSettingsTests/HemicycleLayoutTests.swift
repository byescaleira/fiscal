#if DEBUG
    import Foundation
    import Testing

    @testable import FeatureSettings

    struct HemicycleLayoutTests {
        @Test(arguments: [(252, 176, 1, 513), (75, 1, 3, 81), (0, 0, 0, 513)])
        func placesOneSeatPerMember(yes: Int, no: Int, other: Int, total: Int) {
            let layout = HemicycleLayout(yes: yes, no: no, other: other, total: total)
            #expect(layout.count == total)
            #expect(layout.seatsPerRow.reduce(0, +) == total)
            #expect(layout.count(of: .yes) == yes)
            #expect(layout.count(of: .no) == no)
            #expect(layout.count(of: .other) == other)
            #expect(layout.count(of: .absent) == total - yes - no - other)
        }

        @Test func putsYesOnTheLeftAndNoOnTheRight() {
            let layout = HemicycleLayout(yes: 252, no: 176, other: 1, total: 513)
            let byAngle = layout.seats.sorted { $0.angle > $1.angle }
            #expect(byAngle.prefix(252).allSatisfy { $0.group == .yes })
            #expect(byAngle.suffix(176).allSatisfy { $0.group == .no })
        }

        @Test func countsBothSidesAtTheSamePace() {
            let layout = HemicycleLayout(yes: 252, no: 176, other: 1, total: 513)
            let firstYes = layout.seats.filter { $0.group == .yes }.map(\.rank).sorted()
            let firstNo = layout.seats.filter { $0.group == .no }.map(\.rank).sorted()
            #expect(firstYes.first == 0)
            #expect(firstNo.first == 0)
            #expect(layout.lastRank == 252 + 85 - 1)
        }

        @Test func sendsTheShaderOneEntryPerSeat() {
            let layout = HemicycleLayout(yes: 75, no: 1, other: 3, total: 81)
            #expect(layout.shaderGroups.count == 81)
            #expect(layout.shaderRanks.count == 81)
            #expect(layout.rowStarts.last == 81)
            #expect(layout.rowStarts.count == layout.seatsPerRow.count + 1)
        }

        @Test func marksTheMajorityBetweenTwoSeats() {
            let layout = HemicycleLayout(yes: 252, no: 176, other: 1, total: 513)
            let angle = layout.angle(beforeSeat: 257)
            let sorted = layout.seats.map(\.angle).sorted(by: >)
            #expect(sorted[256] >= angle)
            #expect(angle >= sorted[257])
        }
    }
#endif
