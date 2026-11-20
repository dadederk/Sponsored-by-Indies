import AppKit
import Testing
@testable import SponsoredByIndiesWebsite

struct PartnerArtworkTests {
    private var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    @Test(arguments: ["offer", "participation", "edition", "product", "icon", "logo"])
    func artworkRequiresAnApprovedContributionAndOriginalArtwork(problem: String) throws {
        var catalog = CatalogFixture.showcase()
        catalog.conferences[0].branding?.logoPath = "/conference-logos/sample.svg"
        catalog.projects[0].iconPath = "/app-icons/tool.png"
        _ = try PartnerArtwork(catalog: catalog, editionID: "sample-2027", projectID: "tool")
        var editionID = "sample-2027"
        var projectID = "tool"
        switch problem {
        case "offer": catalog.offers[0].publicationApproved = false
        case "participation": catalog.participations[0].publicationApproved = false
        case "edition": editionID = "sample-2028"
        case "product": projectID = "other"
        case "icon": catalog.projects[0].iconPath = nil
        default: catalog.conferences[0].branding?.logoPath = nil
        }
        #expect(throws: CatalogError.self) {
            try PartnerArtwork(catalog: catalog, editionID: editionID, projectID: projectID)
        }
    }

    @Test @MainActor func repeatedRendersAreByteIdenticalForBothPartnersAndSymbols() throws {
        let catalog = try Catalog.load(from: root.appending(path: "Data"))
        let brand = root.deletingLastPathComponent().appending(path: "assets/brand/sponsored-by-indies/sponsored-by-indies-logo-full-colour-transparent.png")
        for projectID in [nil, "dee"] as [String?] {
            let artwork = try PartnerArtwork(catalog: catalog, editionID: "arctic-2027", projectID: projectID)
            var variants: [Data] = []
            for symbol in PartnerArtwork.Symbol.allCases {
                let first = try artwork.png(symbol: symbol, assets: root.appending(path: "Assets"), brandLogo: brand)
                let repeated = try artwork.png(symbol: symbol, assets: root.appending(path: "Assets"), brandLogo: brand)
                #expect(first == repeated)
                let image = try #require(NSBitmapImageRep(data: first))
                #expect(image.pixelsWide == 1800 && image.pixelsHigh == 1200)
                variants.append(first)
            }
            #expect(variants[0] != variants[1])
        }
        for groupID in ["rocketsim-rockettrace", "azam-books"] {
            let artwork = try PartnerArtwork(catalog: catalog, editionID: "arctic-2027", groupID: groupID)
            #expect(try artwork.png(symbol: .cross, assets: root.appending(path: "Assets"), brandLogo: brand)
                    == artwork.png(symbol: .cross, assets: root.appending(path: "Assets"), brandLogo: brand))
        }
    }

    @Test func batchCoversEveryApprovedProductExactlyOnce() throws {
        let catalog = try Catalog.load(from: root.appending(path: "Data"))
        let batch = try PartnerArtwork.batch(catalog: catalog, editionID: "arctic-2027")
        let products = batch.flatMap { $0.projects.map(\.id) }
        let expected = catalog.visibleProductContributions(for: batch[0].edition).compactMap(\.product.projectID)
        #expect(products.count == Set(products).count)
        #expect(Set(products) == Set(expected))
        #expect(batch.filter { $0.projects.isEmpty }.count == 1)
        #expect(batch.filter { $0.group != nil }.map(\.partnerID).sorted() == ["azam-books", "rocketsim-rockettrace"])
        #expect(batch.count == expected.count - 2 + 1)
        #expect(batch.dropFirst().map(\.partnerID) == batch.dropFirst().map(\.partnerID).sorted())
    }

    @Test(arguments: ["../escape", "/tmp/export", "sample/2027", "sample\\2027", "sample\n"])
    func editionIDsCannotEscapeArtworkExportPaths(id: String) throws {
        var catalog = CatalogFixture.make()
        catalog.conferences[0].branding?.logoPath = "/conference-logos/sample.svg"
        catalog.editions[0].id = id
        catalog.participations[0].editionID = id
        catalog.offers[0].editionID = id
        try catalog.validate()
        #expect(throws: CatalogError.self) {
            try PartnerArtwork(catalog: catalog, editionID: id)
        }
    }

    @Test(arguments: ["sponsored-by-indies", "../escape", "tool\n"])
    func productIDsCannotEscapeOrReplaceTheSponsorExport(id: String) throws {
        var catalog = CatalogFixture.showcase()
        catalog.conferences[0].branding?.logoPath = "/conference-logos/sample.svg"
        catalog.projects[0].id = id
        catalog.projects[0].iconPath = "/app-icons/tool.png"
        catalog.offers[0].projectID = id
        #expect(throws: CatalogError.self) {
            try PartnerArtwork(catalog: catalog, editionID: "sample-2027", projectID: id)
        }
    }

    @Test @MainActor func conferenceLogosCanBindTheirBackgroundColor() throws {
        var catalog = CatalogFixture.make()
        catalog.conferences[0].branding?.logoPath = "/conference-logos/sample.svg"
        catalog.conferences[0].branding?.artworkBackground = "#ffffff"
        let assets = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: assets.appending(path: "conference-logos"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: assets) }
        let vector = #"<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" viewBox="0 0 100 100"><path fill="var(--conference-background, #000000)" d="M0 0H100V100H0Z"/></svg>"#
        try vector.write(to: assets.appending(path: "conference-logos/sample.svg"), atomically: true, encoding: .utf8)
        let artwork = try PartnerArtwork(catalog: catalog, editionID: "sample-2027")
        let brand = root.deletingLastPathComponent()
            .appending(path: "assets/brand/sponsored-by-indies/sponsored-by-indies-logo-full-colour-transparent.png")
        let result = try artwork.png(symbol: .cross, assets: assets, brandLogo: brand)
        let image = try #require(NSBitmapImageRep(data: result))
        #expect(image.pixelsWide == 1800 && image.pixelsHigh == 1200)
        catalog.conferences[0].branding?.background = "#ff0000"
        let changed = try PartnerArtwork(catalog: catalog, editionID: "sample-2027")
        #expect(result != (try changed.png(symbol: .cross, assets: assets, brandLogo: brand)))
    }

    @Test(arguments: ["unknown", "duplicate member", "overlap", "duplicate ID", "unsafe ID", "product ID", "one product", "different makers"])
    func groupsRequireDistinctApprovedMembersAndStableIDs(problem: String) throws {
        var catalog = try Catalog.load(from: root.appending(path: "Data"))
        var groups = try #require(catalog.editions[0].artworkGroups)
        switch problem {
        case "unknown": groups[0].projectIDs[1] = "unknown"
        case "duplicate member": groups[0].projectIDs[1] = groups[0].projectIDs[0]
        case "overlap": groups[1].projectIDs[0] = groups[0].projectIDs[0]
        case "duplicate ID": groups[1].id = groups[0].id
        case "unsafe ID": groups[0].id = "../escape"
        case "product ID": groups[0].id = "dee"
        case "different makers": groups[0].projectIDs[1] = "structured"
        default: groups[0].projectIDs.removeLast()
        }
        catalog.editions[0].artworkGroups = groups
        #expect(throws: CatalogError.self) { try catalog.validate() }
    }

    @Test(arguments: ["offer", "participation"])
    func everyGroupMemberNeedsApprovalForThatEdition(problem: String) throws {
        var catalog = try Catalog.load(from: root.appending(path: "Data"))
        if problem == "offer" {
            for index in catalog.offers.indices where catalog.offers[index].projectID == "rockettrace" {
                catalog.offers[index].publicationApproved = false
            }
        } else {
            for index in catalog.participations.indices where catalog.participations[index].indieID == "antoine-van-der-lee" {
                catalog.participations[index].publicationApproved = false
            }
        }
        #expect(throws: CatalogError.self) {
            try PartnerArtwork(catalog: catalog, editionID: "arctic-2027", groupID: "rocketsim-rockettrace")
        }
    }

    @Test @MainActor func laterBatchFailurePreservesTheWholePreviousSet() throws {
        var catalog = try Catalog.load(from: root.appending(path: "Data"))
        let sponsor = try PartnerArtwork(catalog: catalog, editionID: "arctic-2027")
        let index = try #require(catalog.projects.firstIndex { $0.id == "dee" })
        catalog.projects[index].iconPath = "/app-icons/missing.png"
        let broken = try PartnerArtwork(catalog: catalog, editionID: "arctic-2027", projectID: "dee")
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let previous = Data("Previous complete set".utf8)
        let sentinel = directory.appending(path: "previous.png")
        try previous.write(to: sentinel)
        let brand = root.deletingLastPathComponent().appending(path: "assets/brand/sponsored-by-indies/sponsored-by-indies-logo-full-colour-transparent.png")
        #expect(throws: CatalogError.self) {
            try PartnerArtwork.installBatch([sponsor, broken], in: directory, assets: root.appending(path: "Assets"), brandLogo: brand)
        }
        #expect(try Data(contentsOf: sentinel) == previous)
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path) == ["previous.png"])
    }

    @Test @MainActor func failedRenderPreservesPreviousExport() throws {
        let catalog = try Catalog.load(from: root.appending(path: "Data"))
        let artwork = try PartnerArtwork(catalog: catalog, editionID: "arctic-2027", projectID: "dee")
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let previous = Data("Previous successful export".utf8)
        let image = directory.appending(path: artwork.filename(for: .cross))
        try previous.write(to: image)
        #expect(throws: CatalogError.self) {
            try artwork.install(in: directory, assets: root.appending(path: "Assets"), brandLogo: directory.appending(path: "missing.png"))
        }
        #expect(try Data(contentsOf: image) == previous)
    }

    @Test @MainActor func individualAndBatchExportsShareDescriptiveFilenamesAndRemoveStaleFiles() throws {
        let catalog = try Catalog.load(from: root.appending(path: "Data"))
        let artwork = try PartnerArtwork(catalog: catalog, editionID: "arctic-2027", projectID: "dee")
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let brand = root.deletingLastPathComponent().appending(path: ArtworkPaths.brandFile("logo-full-colour-transparent"))
        #expect(artwork.folder == "assets/social/arctic/2027/partners/dee")
        #expect(ArtworkPaths.partnerDirectory(artwork.conference, edition: artwork.edition) == "assets/social/arctic/2027/partners")
        try artwork.install(in: directory, assets: root.appending(path: "Assets"), brandLogo: brand)
        let cross = directory.appending(path: "arctic-2027-dee-cross.png")
        let individual = try Data(contentsOf: cross)
        #expect(Set(try FileManager.default.contentsOfDirectory(atPath: directory.path))
                == ["arctic-2027-dee-cross.png", "arctic-2027-dee-heart.png", "artwork-index.json"])
        let index = try Data(contentsOf: directory.appending(path: "artwork-index.json"))
        let record = try #require(JSONSerialization.jsonObject(with: index) as? [String: Any])
        let posts = try #require(record["posts"] as? [[String: Any]])
        #expect(posts.first?["projectIDs"] as? [String] == ["dee"])
        #expect(posts.first?["images"] as? [String: String] == ["cross": "arctic-2027-dee-cross.png", "heart": "arctic-2027-dee-heart.png"])
        try artwork.install(in: directory, assets: root.appending(path: "Assets"), brandLogo: brand)
        #expect(try Data(contentsOf: directory.appending(path: "artwork-index.json")) == index)
        try PartnerArtwork.installBatch([artwork], in: directory, assets: root.appending(path: "Assets"), brandLogo: brand)
        #expect(Set(try FileManager.default.contentsOfDirectory(atPath: directory.path)) == ["arctic-2027-dee-cross.png", "artwork-index.json"])
        #expect(try Data(contentsOf: cross) == individual)
    }

    @Test func transparentPaddingIsRemovedWithoutCroppingVisiblePixels() throws {
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let bitmap = try #require(CGContext(data: nil, width: 11, height: 17, bitsPerComponent: 8,
            bytesPerRow: 44, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        bitmap.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        bitmap.fill(CGRect(x: 2, y: 1, width: 4, height: 7))
        let original = try #require(bitmap.makeImage())
        let expected = try #require(NSBitmapImageRep(cgImage: original).colorAt(x: 2, y: 9)?.usingColorSpace(.sRGB))
        let image = try PartnerArtwork.removingTransparentPadding(from: original)
        #expect(image.width == 4 && image.height == 7)
        #expect(image.colorSpace?.name == original.colorSpace?.name)
        let pixels = NSBitmapImageRep(cgImage: image)
        for y in 0..<image.height {
            for x in 0..<image.width {
                let color = try #require(pixels.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
                #expect(color.alphaComponent == 1)
                #expect(abs(color.redComponent - expected.redComponent) < 0.000001)
                #expect(abs(color.greenComponent - expected.greenComponent) < 0.000001)
                #expect(abs(color.blueComponent - expected.blueComponent) < 0.000001)
            }
        }
        bitmap.clear(CGRect(x: 0, y: 0, width: 11, height: 17))
        #expect(throws: CatalogError.self) {
            try PartnerArtwork.removingTransparentPadding(from: #require(bitmap.makeImage()))
        }
    }

    @Test(arguments: ["/conference-logos/../secret.svg", "https://example.org/logo.svg", "/conference-logos/logo.png"])
    func logoPathsStayInsideLocalVectorAssets(path: String) {
        var catalog = CatalogFixture.make()
        catalog.conferences[0].branding?.logoPath = path
        #expect(throws: CatalogError.self) { try catalog.validate() }
    }
}
