#if os(macOS)
    import AppKit
    import FeatureCore
    import FiscalDesignSystem
    import FiscalDomain
    import SwiftUI

    struct ExpensesTable: View {
        @Environment(ExpensesModel.self) private var expenses
        @Environment(\.openURL) private var openURL
        @State private var order: [KeyPathComparator<ExpensesModel.Record>] = ExpensesModel
            .recordOrder
        @State private var selection = Set<ExpensesModel.Record.ID>()

        var body: some View {
            Table(expenses.records(sortedBy: order), selection: $selection, sortOrder: $order) {
                TableColumn("Date", value: \.period) { record in
                    Text(verbatim: record.date)
                        .monospacedDigit()
                        .tableCell()
                }
                TableColumn("Supplier", value: \.supplier) { record in
                    Text(verbatim: record.supplier).tableCell()
                }
                TableColumn("Kind", value: \.category) { record in
                    Text(verbatim: record.category)
                        .foregroundStyle(.secondary)
                        .tableCell()
                }
                TableColumn("Amount", value: \.cents) { record in
                    Text(verbatim: record.value)
                        .monospacedDigit()
                        .tableCell()
                }
                .alignment(.trailing)
            }
            .contextMenu(forSelectionType: ExpensesModel.Record.ID.self) { ids in
                let urls = expenses.receiptURLs(for: ids)
                if !urls.isEmpty {
                    Button("Open Receipt", systemImage: "arrow.up.forward.square") {
                        openReceipts(ids)
                    }
                }
                Button("Copy", systemImage: "doc.on.doc") { copy(ids) }
            } primaryAction: { ids in
                openReceipts(ids)
            }
        }

        private func openReceipts(_ ids: Set<ExpensesModel.Record.ID>) {
            for url in expenses.receiptURLs(for: ids) { openURL(url) }
        }

        private func copy(_ ids: Set<ExpensesModel.Record.ID>) {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(expenses.copyText(for: ids, sortedBy: order), forType: .string)
        }
    }
#endif
