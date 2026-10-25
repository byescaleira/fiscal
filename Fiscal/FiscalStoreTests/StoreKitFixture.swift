import Foundation
import StoreKit
import StoreKitTest

@MainActor
final class StoreKitFixture {
    static let monthly = "fiscal.pro.monthly"
    static let yearly = "fiscal.pro.yearly"

    let session: SKTestSession

    init() throws {
        session = try SKTestSession(configurationFileNamed: "Fiscal")
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
    }

    func plans() async throws -> [String: Product] {
        var products = try await Product.products(for: [Self.monthly, Self.yearly])
        for _ in 0..<20 where products.count < 2 {
            try await Task.sleep(for: .milliseconds(250))
            products = try await Product.products(for: [Self.monthly, Self.yearly])
        }
        return Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
    }
}
