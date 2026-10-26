import FiscalDomain
import Foundation
import Testing

struct PublicFormatTests {
    private let brazil = Locale(identifier: "pt_BR")

    private func plain(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{00A0}", with: " ")
    }

    @Test func formatsCentsAsReais() {
        #expect(plain(PublicFormat.money(cents: 4_636_619, locale: brazil)) == "R$ 46.366,19")
        #expect(plain(PublicFormat.money(cents: 5, locale: brazil)) == "R$ 0,05")
        #expect(plain(PublicFormat.money(cents: -1_050, locale: brazil)) == "-R$ 10,50")
        #expect(PublicFormat.reais(cents: 1_999) == Decimal(string: "19.99"))
    }

    @Test func keepsLargeAmountsExact() {
        #expect(
            plain(PublicFormat.money(cents: 287_400_000_000_001, locale: brazil))
                == "R$ 2.874.000.000.000,01")
    }

    @Test func abbreviatesLargeAmounts() {
        let text = plain(PublicFormat.compactMoney(cents: 19_840_000_000, locale: brazil))
        #expect(text.hasPrefix("R$"))
        #expect(text.contains("198,4"))
    }

    @Test func showsADashForMissingData() {
        #expect(PublicFormat.money(cents: nil) == "—")
        #expect(PublicFormat.compactMoney(cents: nil) == "—")
        #expect(PublicFormat.number(nil) == "—")
        #expect(PublicFormat.percent(nil) == "—")
        #expect(PublicFormat.percent(.nan) == "—")
    }

    @Test func formatsCountsAndShares() {
        #expect(PublicFormat.number(41_230, locale: brazil) == "41.230")
        #expect(plain(PublicFormat.percent(0.875, locale: brazil)) == "87,5%")
    }
}
