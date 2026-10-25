import StoreKit
import Testing

@MainActor
struct CatalogTests {
    @Test func proPlansShareTheGroupWithAWeekFreeAndYearlyOnTop() async throws {
        let plans = try await StoreKitFixture().plans()
        let monthly = try #require(plans[StoreKitFixture.monthly]?.subscription)
        let yearly = try #require(plans[StoreKitFixture.yearly]?.subscription)
        #expect(monthly.subscriptionGroupID == yearly.subscriptionGroupID)
        #expect(monthly.subscriptionPeriod.unit == .month)
        #expect(yearly.subscriptionPeriod.unit == .year)
        #expect(yearly.groupLevel < monthly.groupLevel)
        for plan in [monthly, yearly] {
            let trial = try #require(plan.introductoryOffer)
            #expect(trial.paymentMode == .freeTrial)
            #expect(trial.period.unit == .week)
            #expect(trial.period.value == 1)
        }
    }
}
