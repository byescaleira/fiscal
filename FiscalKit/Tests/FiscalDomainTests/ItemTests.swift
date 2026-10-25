import FiscalDomain
import Testing

struct ItemTests {
    @Test func trimsTheTitle() {
        #expect(Item(title: "  Plan  ").trimmedTitle == "Plan")
    }

    @Test(arguments: ["", "   ", "\n"])
    func rejectsBlankTitles(title: String) {
        #expect(!Item(title: title).isValid)
    }

    @Test func acceptsATitle() {
        #expect(Item(title: "A").isValid)
    }
}
