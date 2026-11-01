import FeatureCore
import FiscalDomain
import Foundation

extension ExpensesModel {
    public struct Record: Identifiable, Equatable, Sendable {
        public let id: String
        public let period: Int
        public let date: String
        public let supplier: String
        public let category: String
        public let document: String
        public let cents: Int
        public let value: String
        public let url: URL?
    }

    public static var recordOrder: [KeyPathComparator<Record>] {
        [KeyPathComparator(\.period, order: .reverse)]
    }

    public var records: [Record] {
        let labels = MoneyText.monthLabels(calendar: calendar)
        return (list?.items ?? [])
            .filter { categoryFilter == nil || $0.category == categoryFilter }
            .map { expense in
                let line = Self.line(expense)
                let month =
                    (1...12).contains(expense.month)
                    ? labels[expense.month - 1] : PublicFormat.missing
                return Record(
                    id: expense.id, period: expense.year * 100 + expense.month,
                    date: "\(month) \(String(expense.year))", supplier: line.supplier,
                    category: line.category, document: line.document, cents: expense.cents,
                    value: line.value, url: line.url)
            }
    }

    public func records(sortedBy order: [KeyPathComparator<Record>]) -> [Record] {
        records.sorted(
            using: order + [
                KeyPathComparator(\.supplier, comparator: .localizedStandard),
                KeyPathComparator(\.id),
            ])
    }

    public var recordsTotal: String {
        PublicFormat.money(cents: records.map(\.cents).reduce(0, +))
    }

    public var recordsSubtitle: String {
        [scopeTitle, recordsTotal].joined(separator: " · ")
    }

    public func receiptURLs(for ids: Set<Record.ID>) -> [URL] {
        records.filter { ids.contains($0.id) }.compactMap(\.url)
    }

    public func copyText(for ids: Set<Record.ID>, sortedBy order: [KeyPathComparator<Record>])
        -> String
    {
        records(sortedBy: order)
            .filter { ids.contains($0.id) }
            .map { [$0.date, $0.supplier, $0.category, $0.document, $0.value] }
            .map { $0.joined(separator: "\t") }
            .joined(separator: "\n")
    }
}
