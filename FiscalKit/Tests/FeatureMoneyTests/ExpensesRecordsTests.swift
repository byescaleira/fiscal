import FeatureCore
import FiscalData
import FiscalDomain
import Foundation
import Testing

@testable import FeatureMoney

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct ExpensesRecordsTests {
    private let now = Date(timeIntervalSince1970: 1_792_917_720)

    private func loaded() async -> ExpensesModel {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo") ?? .gmt
        let model = ExpensesModel(
            slug: "tabata-amaral", year: 2_026,
            service: ShowcasePublicData(scenario: .normal, now: now, calendar: calendar),
            calendar: calendar)
        await model.load()
        return model
    }

    @Test func everyReceiptIsARecordNewestMonthFirst() async throws {
        let model = await loaded()
        let list = try #require(model.list)
        let records = model.records(sortedBy: ExpensesModel.recordOrder)
        #expect(records.count == list.items.count)
        #expect(Set(records.map(\.id)).count == records.count)
        #expect(records.map(\.period) == records.map(\.period).sorted(by: >))
        let first = try #require(records.first)
        #expect(first.date.hasSuffix(" 2026"))
        #expect(first.period / 100 == 2_026)
    }

    @Test func sortingByAmountOrdersTheCents() async {
        let model = await loaded()
        let ascending = model.records(sortedBy: [KeyPathComparator(\.cents)])
        #expect(ascending.map(\.cents) == ascending.map(\.cents).sorted())
        let descending = model.records(sortedBy: [KeyPathComparator(\.cents, order: .reverse)])
        #expect(descending.map(\.cents) == ascending.map(\.cents).sorted(by: >))
    }

    @Test func sortingBySupplierIsAlphabetical() async {
        let model = await loaded()
        let records = model.records(
            sortedBy: [KeyPathComparator(\.supplier, comparator: .localizedStandard)])
        let suppliers = records.map(\.supplier)
        #expect(
            zip(suppliers, suppliers.dropFirst()).allSatisfy {
                $0.localizedStandardCompare($1) != .orderedDescending
            })
    }

    @Test func theKindFilterNarrowsTheRecordsAndTheSubtitleTotal() async throws {
        let model = await loaded()
        #expect(model.recordsSubtitle == "\(model.scopeTitle) · \(model.total)")
        let kind = try #require(model.categoryNames.first)
        model.categoryFilter = kind
        let records = model.records
        #expect(!records.isEmpty)
        #expect(records.allSatisfy { $0.category == kind })
        let cents = records.map(\.cents).reduce(0, +)
        #expect(model.recordsTotal == PublicFormat.money(cents: cents))
        #expect(model.recordsSubtitle.hasPrefix("2026 · \(kind) · "))
    }

    @Test func onlyReceiptsWithADocumentOpen() async throws {
        let model = await loaded()
        let records = model.records
        let withURL = try #require(records.first { $0.url != nil })
        let withoutURL = try #require(records.first { $0.url == nil })
        #expect(model.receiptURLs(for: [withURL.id]) == [withURL.url].compactMap(\.self))
        #expect(model.receiptURLs(for: [withoutURL.id]).isEmpty)
        #expect(model.receiptURLs(for: [withURL.id, withoutURL.id]).count == 1)
    }

    @Test func copyingKeepsTheTableOrderOneLinePerReceipt() async throws {
        let model = await loaded()
        let order = [KeyPathComparator(\ExpensesModel.Record.cents, order: .reverse)]
        let top = Array(model.records(sortedBy: order).prefix(3))
        let text = model.copyText(for: Set(top.map(\.id)), sortedBy: order)
        let lines = text.split(separator: "\n").map(String.init)
        #expect(lines.count == top.count)
        let first = try #require(top.first)
        #expect(
            lines.first
                == [first.date, first.supplier, first.category, first.document, first.value]
                .joined(separator: "\t"))
        #expect(model.copyText(for: [], sortedBy: order).isEmpty)
    }
}
