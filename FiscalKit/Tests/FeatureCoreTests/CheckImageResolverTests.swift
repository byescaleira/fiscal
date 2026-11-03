import FeatureCore
import Foundation
import Testing

struct CheckImageResolverTests {
    @Test func readsTheCoverOfACheck() {
        let html =
            #"<head><meta property="og:image:width" content="1200"/>"#
            + #"<meta property="og:image" content="https://projetocomprova.com.br/a/capa.jpg"/></head>"#
        #expect(
            CheckImageResolver.imageURL(in: html)
                == URL(string: "https://projetocomprova.com.br/a/capa.jpg"))
    }

    @Test func refusesAnImageFromAnotherSite() {
        let html = #"<meta content="https://outro.example/capa.jpg" property="og:image"/>"#
        #expect(CheckImageResolver.imageURL(in: html) == nil)
        #expect(CheckImageResolver.imageURL(in: "<p>sem capa</p>") == nil)
    }

    @Test func onlyAsksTheFactCheckerOverHTTPS() throws {
        let page = try #require(URL(string: "https://projetocomprova.com.br/publicacoes/a/"))
        let plain = try #require(URL(string: "http://projetocomprova.com.br/publicacoes/a/"))
        let other = try #require(URL(string: "https://www.camara.leg.br/noticias/1"))
        #expect(CheckImageResolver.accepts(page))
        #expect(!CheckImageResolver.accepts(plain))
        #expect(!CheckImageResolver.accepts(other))
    }

    @Test func aPageFromAnotherSiteIsNeverFetched() async throws {
        let other = try #require(URL(string: "https://www.camara.leg.br/noticias/1"))
        let image = await CheckImageResolver().imageURL(for: other)
        #expect(image == nil)
    }
}
