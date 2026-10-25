import FiscalResource
import Foundation
import Testing

struct ArtCatalogTests {
    private static let resourceRoot = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "Sources/FiscalResource")

    private static let assetCatalog = resourceRoot.appending(path: "Assets/Art.xcassets")

    private static let openLicenses: Set<String> = ["CC BY-SA 4.0", "CC BY 4.0", "CC0"]

    private static let regions: [Set<String>] = [
        ["ac", "am", "ap", "pa", "ro", "rr", "to"],
        ["al", "ba", "ce", "ma", "pb", "pe", "pi", "rn", "se"],
        ["df", "go", "ms", "mt"],
        ["es", "mg", "rj", "sp"],
        ["pr", "rs", "sc"],
    ]

    private static let fixture = #"""
        {
          "collections": [
            { "id": "paisagens", "name": "Paisagens", "leadWork": "marinha", "palette": ["#6F8FA6", "#C9B48A"] },
            { "id": "povo", "name": "Gente do Brasil", "leadWork": "caipira", "palette": ["#5A4632", "#B08A5B", "#2E2A24"] }
          ],
          "works": [
            {
              "id": "marinha", "asset": "art-marinha", "title": "Marinha, Guarujá", "artist": "Almeida Júnior",
              "artistLife": "1850–1899", "year": "1895", "collection": "paisagens",
              "holder": "Pinacoteca do Estado de São Paulo",
              "sourceUrl": "https://commons.wikimedia.org/wiki/File:Marinha.jpg",
              "fileUrl": "https://upload.wikimedia.org/marinha.jpg", "license": "PD-Art (PD-old-100-expired)",
              "licenseUrl": "https://creativecommons.org/publicdomain/mark/1.0/",
              "credit": "Almeida Júnior, Marinha, Guarujá (1895). Domínio público. Acervo Pinacoteca do Estado de São Paulo via Wikimedia Commons."
            },
            {
              "id": "caipira", "asset": "art-caipira", "title": "Caipira Picando Fumo", "artist": "Almeida Júnior",
              "artistLife": "1850–1899", "year": "1893", "collection": "povo",
              "holder": "Pinacoteca do Estado de São Paulo",
              "sourceUrl": "https://commons.wikimedia.org/wiki/File:Caipira.jpg",
              "fileUrl": "https://upload.wikimedia.org/caipira.jpg", "license": "PD-Art (PD-old-100-expired)",
              "licenseUrl": "https://creativecommons.org/publicdomain/mark/1.0/",
              "credit": "Almeida Júnior, Caipira Picando Fumo (1893). Domínio público. Acervo Pinacoteca do Estado de São Paulo via Wikimedia Commons."
            },
            {
              "id": "leitura", "asset": "art-leitura", "title": "Leitura", "artist": "Almeida Júnior",
              "artistLife": "1850–1899", "year": "1892", "collection": "povo",
              "holder": "Pinacoteca do Estado de São Paulo",
              "sourceUrl": "https://commons.wikimedia.org/wiki/File:Leitura.jpg",
              "fileUrl": "https://upload.wikimedia.org/leitura.jpg", "license": "PD-Art (PD-old-100-expired)",
              "licenseUrl": "https://creativecommons.org/publicdomain/mark/1.0/",
              "credit": "Almeida Júnior, Leitura (1892). Domínio público. Acervo Pinacoteca do Estado de São Paulo via Wikimedia Commons."
            }
          ]
        }
        """#

    private static func imagesetNames() throws -> Set<String> {
        let entries = try FileManager.default.contentsOfDirectory(
            atPath: assetCatalog.path(percentEncoded: false))
        return Set(
            entries.filter { $0.hasSuffix(".imageset") }
                .map { String($0.dropLast(".imageset".count)) })
    }

    @Test func decodesTheManifestShape() throws {
        let catalog = try ArtCatalog.decode(Data(Self.fixture.utf8))
        #expect(catalog.collections.map(\.id) == ["paisagens", "povo"])
        #expect(catalog.works(in: "povo").map(\.id) == ["caipira", "leitura"])
        #expect(catalog.assets == ["art-marinha", "art-caipira", "art-leitura"])
        let povo = try #require(catalog.collection(id: "povo"))
        #expect(catalog.leadWork(of: povo)?.title == "Caipira Picando Fumo")
        #expect(catalog.work(id: "missing") == nil)
        #expect(catalog.collection(id: "missing") == nil)
    }

    @Test func bundledManifestMatchesTheAssetCatalog() throws {
        let catalog = try ArtCatalog.bundled()
        #expect(catalog.assets == (try Self.imagesetNames()))
        #expect(catalog.assets.count == catalog.works.count)
    }

    @Test func everyImagesetCarriesItsJPEG() throws {
        for name in try Self.imagesetNames() {
            let folder = Self.assetCatalog.appending(path: name + ".imageset")
            let contents = try Data(contentsOf: folder.appending(path: "Contents.json"))
            let object = try #require(
                try JSONSerialization.jsonObject(with: contents) as? [String: Any])
            let images = try #require(object["images"] as? [[String: Any]])
            let filenames = images.compactMap { $0["filename"] as? String }
            #expect(filenames == [name + ".jpg"])
            #expect(
                FileManager.default.fileExists(
                    atPath: folder.appending(path: name + ".jpg").path(percentEncoded: false)))
        }
    }

    @Test func bundledCollectionsAreConsistent() throws {
        let catalog = try ArtCatalog.bundled()
        #expect(Set(catalog.works.map(\.id)).count == catalog.works.count)
        #expect(Set(catalog.collections.map(\.id)).count == catalog.collections.count)
        for work in catalog.works {
            #expect(catalog.collection(id: work.collection) != nil, "\(work.id)")
        }
        for collection in catalog.collections {
            #expect(!collection.name.isEmpty)
            #expect(
                catalog.leadWork(of: collection)?.collection == collection.id, "\(collection.id)")
            #expect((2...3).contains(collection.palette.count), "\(collection.id)")
            for color in collection.palette {
                #expect(try #/^#[0-9A-F]{6}$/#.wholeMatch(in: color) != nil, "\(color)")
            }
        }
    }

    @Test func bundledCreditsNameTheWorkAndThePublicDomain() throws {
        for work in try ArtCatalog.bundled().works where !work.isPhoto {
            #expect(work.asset == "art-" + work.id)
            #expect(work.kind == .artwork)
            #expect(work.collection == "acervo-historico")
            #expect(work.series != nil)
            #expect(
                work.credit.hasPrefix(
                    "\(work.artist), \(work.title) (\(work.year)). Domínio público. "))
            #expect(work.credit.hasSuffix(" via Wikimedia Commons."))
            #expect(work.sourceUrl.host() == "commons.wikimedia.org")
            #expect(work.fileUrl.host()?.hasSuffix(".wikimedia.org") == true)
            #expect(work.fileUrl.query() == nil)
            #expect(work.licenseUrl.scheme == "https")
        }
    }

    @Test func bundledPhotosCarryTheOpenLicenseAndTheirAuthor() throws {
        let photos = try ArtCatalog.bundled().works.filter(\.isPhoto)
        #expect(!photos.isEmpty)
        for photo in photos {
            #expect(photo.asset == "art-" + photo.id, "\(photo.id)")
            #expect(photo.collection == "brasil-agora", "\(photo.id)")
            #expect(Self.openLicenses.contains(photo.license), "\(photo.id)")
            #expect(photo.licenseUrl.host() == "creativecommons.org", "\(photo.id)")
            #expect(photo.lifeSpan == nil)
            #expect(photo.author?.isEmpty == false, "\(photo.id)")
            #expect(photo.event?.hasPrefix("Wiki Loves Earth 202") == true, "\(photo.id)")
            #expect(photo.place?.isEmpty == false, "\(photo.id)")
            #expect(photo.credit.hasPrefix("Foto: \(photo.artist)"), "\(photo.id)")
            #expect(photo.credit.contains(photo.license), "\(photo.id)")
            #expect(photo.credit.contains(photo.event ?? "-"), "\(photo.id)")
            #expect(photo.credit.hasSuffix(" via Wikimedia Commons."), "\(photo.id)")
            #expect(photo.sourceUrl.host() == "commons.wikimedia.org", "\(photo.id)")
            #expect(photo.fileUrl.host()?.hasSuffix(".wikimedia.org") == true, "\(photo.id)")
        }
    }

    @Test func brasilAgoraCoversStatesFromEveryRegion() throws {
        let catalog = try ArtCatalog.bundled()
        let photos = catalog.works(in: "brasil-agora")
        let states = photos.compactMap(\.uf)
        #expect(states.count == photos.count)
        #expect(Set(states).count == states.count)
        #expect(states.count >= 12)
        for region in Self.regions {
            #expect(!region.isDisjoint(with: states), "\(region)")
        }
        #expect(catalog.works(forState: "MA").count == 1)
    }

    @Test func publicDomainBecomesTheHistoricalReserve() throws {
        let catalog = try ArtCatalog.bundled()
        #expect(catalog.collections.map(\.id) == ["brasil-agora", "acervo-historico"])
        #expect(catalog.collection(id: "acervo-historico")?.isReserve == true)
        #expect(catalog.featuredCollections.map(\.id) == ["brasil-agora"])
        #expect(catalog.works(in: "acervo-historico").count == 20)
        let series = try #require(catalog.series)
        #expect(series.map(\.id) == ["civica", "povo", "paisagens", "historia"])
        for item in series {
            #expect(!catalog.works(inSeries: item.id).isEmpty, "\(item.id)")
        }
    }

    @Test func everyWorkHasImageCreditLicenseAndLink() throws {
        let catalog = try ArtCatalog.bundled()
        let imagesets = try Self.imagesetNames()
        for work in catalog.works {
            #expect(imagesets.contains(work.asset), "\(work.id)")
            #expect(!work.credit.isEmpty, "\(work.id)")
            #expect(!work.license.isEmpty, "\(work.id)")
            #expect(work.sourceUrl.scheme == "https", "\(work.id)")
            #expect(work.licenseUrl.scheme == "https", "\(work.id)")
        }
    }

    @Test func collectionStaysUnderTheSizeBudget() throws {
        var total = 0
        for name in try Self.imagesetNames() {
            let image = Self.assetCatalog.appending(path: "\(name).imageset/\(name).jpg")
            let attributes = try FileManager.default.attributesOfItem(
                atPath: image.path(percentEncoded: false))
            total += (attributes[.size] as? Int) ?? 0
        }
        #expect(total < 25_000_000)
    }
}
