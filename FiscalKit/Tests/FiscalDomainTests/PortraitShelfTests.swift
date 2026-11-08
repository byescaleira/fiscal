import Testing

@testable import FiscalDomain

struct PortraitShelfTests {
    @Test(arguments: ["soraya-thronicke", "nelsinho-trad", "deputado-1"])
    func aPublishedSlugBecomesAFileName(slug: String) {
        #expect(PortraitShelf.isSafe(slug))
    }

    @Test(arguments: ["", "../escape", "a/b", "Soraya", "café", "x.png"])
    func anyOtherTextNeverBecomesAPath(slug: String) {
        #expect(!PortraitShelf.isSafe(slug))
        #expect(PortraitShelf.url(for: slug) == nil)
    }
}
